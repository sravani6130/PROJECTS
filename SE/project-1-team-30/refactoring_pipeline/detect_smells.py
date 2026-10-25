import os
import subprocess
import csv
import shutil

# Path to DesigniteJava JAR
DESIGNITE_JAR = os.path.join(os.path.dirname(__file__), "DesigniteJava.jar")

# Smells considered "Important" or architectural in nature
# We prioritize these over minor ones like "Unutilized Abstraction" or "Feature Envy"
PRIORITY_SMELLS = [
    "Insufficient Modularization",
    "Broken Hierarchy",
    "Cyclic Hierarchy",
    "Deficient Encapsulation",
    "Broken Modularization",
    "Unnecessary Abstraction",
    "Imperative Abstraction",
]

def detect_smells(directory):
    """
    Runs DesigniteJava on the given directory and parses DesignSmells.csv.
    Filters for architectural and high-priority design smells.
    """
    smells = []
    
    # Absolute path to directory to scan
    abs_input = os.path.abspath(directory)
    
    # Temporary output directory
    output_dir = os.path.join(os.path.dirname(__file__), "temp_designite_output")
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)
    
    try:
        # 1. Run Designite
        print(f"Running Designite on {abs_input}...")
        cmd = ["java", "-jar", DESIGNITE_JAR, "-i", abs_input, "-o", output_dir]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        
        if result.returncode != 0:
            print(f"Designite failed with return code {result.returncode}")
            print(f"Stderr: {result.stderr.decode('utf-8', errors='ignore')}")
        
        # 2. Parse DesignSmells.csv
        csv_path = os.path.join(output_dir, "DesignSmells.csv")
        if os.path.exists(csv_path):
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    smell_type = row['Smell']
                    
                    # Only consider smells in our priority list
                    if smell_type in PRIORITY_SMELLS:
                        smells.append({
                            "file": row['File'],
                            "smell": smell_type,
                            "details": row['Description']
                        })
            print(f"Parsed {len(smells)} priority smells from Designite output.")
        else:
            print(f"Warning: DesignSmells.csv not found at {csv_path}")
            # List files in output_dir to see what WAS generated
            if os.path.exists(output_dir):
                print(f"Contents of temporary output directory {output_dir}: {os.listdir(output_dir)}")
            
    except Exception as e:
        print(f"Error running Designite: {e}")
    finally:
        # 3. Cleanup
        if os.path.exists(output_dir):
            shutil.rmtree(output_dir)
            
    # Sort priority smells to the top (if we had a mix, but currently we filter)
    return smells

if __name__ == "__main__":
    # Scan the 'app' directory as it's the main project source
    detected = detect_smells("app")
    for s in detected:
        print(f"[{s['smell']}] {s['file']}: {s['details']}")
