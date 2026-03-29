import pandas as pd
import argparse
import sys
from itertools import combinations

class STUIndex:
    def __init__(self, max_level=5, lambda_param=5, alpha=10):
        self.max_level = max_level
        self.lambda_param = lambda_param
        self.alpha = alpha
        self.STU = {}
    
    def build_index(self, items, prices, slots, transactions):
        for level in range(1, self.max_level + 1):
            self.STU[level] = []
        
        self._build_first_level(items, prices, slots, transactions)
        
        for level in range(2, self.max_level + 1):
            self._build_higher_level(level, items, prices, slots, transactions)
        
        return self.STU
    
    def _build_first_level(self, items, prices, slots, transactions):
        list_itemset = {item: {'f': 0, 'nr': 0} for item in items}
        
        for transaction in transactions:
            items_in_transaction = transaction['items']
            for item in items_in_transaction:
                if slots[item] == 1:
                    list_itemset[item]['f'] += transaction['frequency']
                    list_itemset[item]['nr'] += (prices[item]/slots[item]) * transaction['frequency']
        
        total_revenue = sum(itemset['nr'] for itemset in list_itemset.values())
        threshold = (total_revenue/len(items)) + (self.alpha/100 * (total_revenue/len(items)))
        
        filtered_items = []
        for item, values in list_itemset.items():
            if values['nr'] >= threshold:
                filtered_items.append({
                    'itemset': frozenset([item]),
                    'f': values['f'],
                    'nr': values['nr'],
                    'nr_per_slot': values['nr']/slots[item] if slots[item] > 0 else 0
                })
        
        filtered_items.sort(key=lambda x: x['nr_per_slot'], reverse=True)
        self.STU[1] = filtered_items[:self.lambda_param]
    
    def _build_higher_level(self, level, items, prices, slots, transactions):
        list_itemset = {}
        
        if level == 2:
            level1_items = [list(item['itemset'])[0] for item in self.STU[1]]
            
            for combo in combinations(level1_items, 2):
                total_slots = sum(slots[item] for item in combo)
                if total_slots == level:
                    list_itemset[frozenset(combo)] = {'f': 0, 'nr': 0}
            
            for item in items:
                if slots[item] == level:
                    list_itemset[frozenset([item])] = {'f': 0, 'nr': 0}
        else:
            for item in items:
                if slots[item] == level:
                    list_itemset[frozenset([item])] = {'f': 0, 'nr': 0}
            
            for lower_level1 in range(1, level):
                lower_level2 = level - lower_level1
                
                if lower_level2 >= 1 and lower_level2 < level:
                    itemsets1 = [item['itemset'] for item in self.STU[lower_level1]]
                    itemsets2 = [item['itemset'] for item in self.STU[lower_level2]]
                    
                    for itemset1 in itemsets1:
                        for itemset2 in itemsets2:
                            if not itemset1.intersection(itemset2):
                                new_itemset = frozenset(itemset1.union(itemset2))
                                
                                slot_size = sum(slots[item] for item in new_itemset)
                                if slot_size == level:
                                    list_itemset[new_itemset] = {'f': 0, 'nr': 0}
        
        for transaction in transactions:
            trans_items = frozenset(transaction['items'])
            
            for itemset in list_itemset:
                if itemset.issubset(trans_items):
                    list_itemset[itemset]['f'] += transaction['frequency']
                    price = sum(prices[i] for i in itemset)
                    slots_required = sum(slots[i] for i in itemset)
                    list_itemset[itemset]['nr'] += (price / slots_required) * transaction['frequency']
        
        if list_itemset:
            total_revenue = sum(values['nr'] for values in list_itemset.values())
            threshold = (total_revenue / len(list_itemset)) + (self.alpha / 100 * (total_revenue / len(list_itemset)))
            
            filtered_itemsets = []
            for itemset, values in list_itemset.items():
                if values['nr'] >= threshold:
                    slot_size = sum(slots[i] for i in itemset)
                    filtered_itemsets.append({
                        'itemset': itemset,
                        'f': values['f'],
                        'nr': values['nr'],
                        'nr_per_slot': values['nr'] / slot_size if slot_size > 0 else 0
                    })
            
            filtered_itemsets.sort(key=lambda x: x['nr_per_slot'], reverse=True)
            self.STU[level] = filtered_itemsets[:self.lambda_param]
        else:
            self.STU[level] = []


class TIPDS:
    def __init__(self, max_level=5, lambda_param=5, alpha=10):
        self.max_level = max_level
        self.lambda_param = lambda_param
        self.alpha = alpha
    
    def place_items(self, items, prices, slots, transactions, premium_slots, existing_STU=None):
        if existing_STU is None:
            stu_index = STUIndex(self.max_level, self.lambda_param, self.alpha)
            STU = stu_index.build_index(items, prices, slots, transactions)
        else:
            STU = existing_STU
        
        placement = []
        remaining_slots = premium_slots
        
        j = 0
        while remaining_slots > 0:
            for i in range(1, self.max_level + 1):
                if j < len(STU[i]):
                    itemset = STU[i][j]['itemset']
                    slot_size = sum(slots[item] for item in itemset)
                    
                    if slot_size <= remaining_slots:
                        placement.append({
                            'items': list(itemset),
                            'slots_used': slot_size,
                            'net_revenue': STU[i][j]['nr'],
                            'nr_per_slot': STU[i][j]['nr_per_slot']
                        })
                        remaining_slots -= slot_size
                    
                    if remaining_slots <= 0:
                        break
            
            j += 1
            
            if all(j >= len(STU[i]) for i in range(1, self.max_level + 1)):
                break
        
        return placement


def load_dataset(items_file, transactions_file):
    # Load items data
    items_df = pd.read_csv(items_file)
    
    items = []
    prices = {}
    slots = {}
    
    for _, row in items_df.iterrows():
        item = str(row['Item'])
        items.append(item)
        prices[item] = float(row['Price'])
        slots[item] = int(row['Slots'])
    
    # Load transactions data
    transactions_df = pd.read_csv(transactions_file)
    
    transactions = []
    for _, row in transactions_df.iterrows():
        tid = row['TID']
        items_list = [item.strip() for item in row['Transaction'].split(',')]
        frequency = row['Frequency']
        
        # If 'Revenue' column exists, use it; otherwise calculate it
        if 'Revenue' in transactions_df.columns:
            revenue = row['Revenue']
        else:
            # Calculate revenue based on items and prices
            revenue = sum(prices.get(item, 0) for item in items_list) * frequency
        
        transactions.append({
            'tid': tid,
            'items': items_list,
            'frequency': frequency,
            'nr': revenue
        })
    
    return items, prices, slots, transactions


def main():
    # Simple positional argument parsing
    if len(sys.argv) < 4:
        print("Usage: python script.py <items_csv_path> <transactions_csv_path> <premium_slots>")
        print("Example: python script.py items.csv transactions.csv 10")
        sys.exit(1)
    
    items_file = sys.argv[1]
    transactions_file = sys.argv[2]
    premium_slots = int(sys.argv[3])
    
    # Default algorithm parameters
    max_level = 10
    lambda_param = 10
    alpha = 3
    
    # Optional algorithm parameters
    if len(sys.argv) > 4:
        max_level = int(sys.argv[4])
    if len(sys.argv) > 5:
        lambda_param = int(sys.argv[5])
    if len(sys.argv) > 6:
        alpha = float(sys.argv[6])
    
    try:
        # Load dataset from specified files
        print(f"Loading data from {items_file} and {transactions_file}...")
        items, prices, slots, transactions = load_dataset(items_file, transactions_file)
        
        # Build STU index
        print("Building STU index...")
        stu_index = STUIndex(max_level, lambda_param, alpha)
        STU = stu_index.build_index(items, prices, slots, transactions)
        
        # Place items
        print(f"Placing items in {premium_slots} premium slots...")
        tipds = TIPDS(max_level, lambda_param, alpha)
        placement = tipds.place_items(items, prices, slots, transactions, premium_slots, STU)
        
        # Print results
        print("\nTIPDS Placement Results:")
        print(f"Total premium slots available: {premium_slots}")
        
        total_slots_used = 0
        total_revenue = 0
        
        for i, p in enumerate(placement):
            items_str = ', '.join(sorted(p['items']))
            print(f"{i+1}. Items: {items_str}")
            print(f"   Slots used: {p['slots_used']}")
            print(f"   Net Revenue: {p['net_revenue']:.2f}")
            print(f"   Net Revenue per Slot: {p['nr_per_slot']:.2f}")
            
            total_slots_used += p['slots_used']
            total_revenue += p['net_revenue']
        
        print(f"\nTotal slots used: {total_slots_used}/{premium_slots}")
        print(f"Total expected revenue: {total_revenue:.2f}")
        print(f"Average revenue per slot: {total_revenue/total_slots_used if total_slots_used > 0 else 0:.2f}")
        
    except FileNotFoundError as e:
        print(f"Error: {e}")
        print("Please make sure the specified files exist and are accessible.")
    except Exception as e:
        print(f"An error occurred: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()