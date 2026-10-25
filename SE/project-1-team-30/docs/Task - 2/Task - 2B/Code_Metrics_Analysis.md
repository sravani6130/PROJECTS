# Task 2B: Code Metrics Analysis

## Overview

This document shows our code metrics analysis for the Apache Roller project. We used three popular code analysis tools: **CodeMR**, **PMD**, and **Checkstyle**. We picked 6 key metrics that tell us about code quality, how easy the code is to maintain, and how well it follows object-oriented design rules.

---

## Tools We Used

| Tool | What It Does |
|------|--------------|
| **CodeMR** | Checks OO metrics (Chidamber & Kemerer suite), coupling, cohesion, and complexity |
| **PMD** | Finds code quality issues, bad practices, and common mistakes |
| **Checkstyle** | Checks code style, formatting, and Javadoc comments |

---

## Our Project Summary

| Metric | Value |
|--------|-------|
| **Total Classes/Interfaces** | 542 |
| **Total Packages** | 64 |
| **Lines of Code** | 33,625 |
| **External Packages** | 91 |
| **External Entities** | 278 |
| **Problem Classes** | 12 |
| **Major Problem Classes** | 0 |

---

## 6 Key Code Metrics Analysis

### 1. Coupling Between Object Classes (CBO)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

**Definition:** CBO counts how many other classes a class depends on. High coupling means classes are too tightly connected to each other.

| CBO Level | Class Count | Lines of Code |
|-----------|-------------|---------------|
| Low (Good) | 418 | 17,632 |
| Medium-Low | 83 | 7,753 |
| Medium | 34 | 5,675 |
| High (Bad) | 9 | 2,889 |
| Very High | 0 | 0 |

**Findings:**
- **77%** of classes (418 out of 542) have low coupling, which is great for modular design
- **9 classes** have high coupling, covering 2,889 lines of code
- These problem classes are mainly in the JPA and UI modules

**Implications:**
- **Code Quality:** When classes are too connected, changing one class can break others. This makes bugs more likely.
- **Maintenance:** Tightly coupled code is hard to change. Fixing one thing often means fixing many other things too.
- **Performance:** Coupling doesn't slow down the code directly, but it can slow down build times and use more memory.

#### **Insights on the Project's current state:**
Our project has good modular design with 77% of classes having low coupling. The 9 high-coupling classes (only 1.7% of total) are in the JPA persistence layer (`JPAPersistenceStrategy`, `JPAWebloggerImpl`) and UI modules. This makes sense since these parts need to connect with many other components. The coupling numbers show our codebase is mature with clear boundaries between modules. So, the persistence layer could use some interface abstractions to make it better.

#### **Refactoring Guidance:** 
We should refactor these 9 high-coupling classes using dependency injection and interface abstractions.

---

### 2. Lack of Cohesion of Methods (LCOM)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

**Definition:** LCOM checks if methods in a class work together or do unrelated things. High LCOM means a class is probably doing too many different jobs.

| LCOM Level | Class Count | Lines of Code |
|------------|-------------|---------------|
| Excellent (Low LCOM) | 484 | 24,291 |
| Medium-Low | 36 | 4,963 |
| Medium | 19 | 3,040 |
| High (Bad) | 4 | 1,456 |
| Very High | 1 | 199 |

**Findings:**
- **89%** of classes (484 out of 542) have excellent cohesion
- **5 classes** have cohesion problems (1,655 lines of code total)
- The worst class (199 lines) probably does too many unrelated things

**Implications:**
- **Code Quality:** When a class does too many things, it breaks the Single Responsibility Principle. Such classes are harder to understand and more likely to have bugs.
- **Maintenance:** Low cohesion makes it hard to figure out what a class is supposed to do. Changes can cause unexpected side effects.
- **Performance:** While not directly a speed issue, classes with poor cohesion often have unused or duplicate code.

#### **Insights on the Project's current state:**
Our project has good cohesion overall with 89% of classes staying focused on one job. The 5 problem classes are probably utility or manager classes that took on extra work over time. Having only 1 class with very high LCOM tells us we mostly avoided the "God class" problem (where one class does everything). This shows our team followed good OO design practices.

#### **Refactoring Guidance:** 
We should split the classes with high LCOM into smaller, focused classes using the Extract Class pattern.

---

### 3. Weighted Methods per Class (WMC) / Cyclomatic Complexity

**Source:** CodeMR

**Definition:** WMC adds up the complexity of all methods in a class. Higher numbers mean the class has more complex logic that's harder to understand.

| Complexity Level | Class Count | Lines of Code |
|------------------|-------------|---------------|
| Low Complexity | 385 | 16,984 |
| Medium Complexity | 151 | 14,431 |
| High Complexity | 7 | 2,191 |
| Very High Complexity | 1 | 343 |

**Findings:**
- **71%** of classes have low complexity (easy to work with)
- **8 classes** have high or very high complexity (2,534 lines of code)
- One class with 343 lines is way too complex

**Quality Breakdown:**
| Quality Category | Class Count | Lines of Code |
|-----------------|-------------|---------------|
| High Coupling + High Complexity | 1 | 343 |
| High Coupling Only | 8 | 2,546 |
| Good Quality | 533 | 31,045 |

**Implications:**
- **Code Quality:** Complex code has more bugs. It's hard to test every possible path through complex methods.
- **Maintenance:** High complexity means developers spend more time understanding the code before they can fix or extend it.
- **Performance:** Complex methods with lots of if-else and loops can run slower. They're also harder to optimize.

#### **Insights on the Project's current state:**
Our project has **manageable complexity** with 71% of classes in the low-complexity range. The 8 classes with high complexity (1.5% of total) probably contain core business logic or framework code. The single class with both high coupling and high complexity (343 lines) needs our attention right away. Overall, most of our business logic is well organized, though some older parts may need cleanup.

#### **Refactoring Guidance:** 
Breaking down complex methods using Extract Method. We can also use Strategy or State patterns to simplify conditional logic.

---

### 4. Code Style Violations

**Source:** PMD (1,555 total violations) + Checkstyle (47,082 total violations)

**Top PMD Issues:**

| Rule | Count | Type |
|------|-------|------|
| GuardLogStatement | 518 | Best Practice |
| ProperLogger | 217 | Error Prone |
| UselessParentheses | 121 | Code Style |
| CloseResource | 119 | Error Prone |
| LiteralsFirstInComparisons | 70 | Best Practice |
| UncommentedEmptyConstructor | 64 | Documentation |
| PreserveStackTrace | 46 | Error Prone |
| EmptyCatchBlock | 38 | Error Prone |

**PMD Issues by Type:**

| Category | Count | Percentage |
|----------|-------|------------|
| Best Practices | 704 | 45.3% |
| Error Prone | 445 | 28.6% |
| Code Style | 261 | 16.8% |
| Documentation | 113 | 7.3% |
| Design | 29 | 1.9% |
| Multithreading | 3 | 0.2% |

**Implications:** 
- **Code Quality:** Style issues often hide bigger problems. The 119 CloseResource violations could cause memory leaks. The 38 empty catch blocks hide errors that could crash production.
- **Maintenance:** Messy code style makes code reviews harder. Issues like extra parentheses (121) distract from the actual logic.
- **Performance:** Unguarded log statements (518) create unnecessary work even when logging is turned off.

#### **Insights on the Project's current state:**
Our project has **some areas that need work**. The 518 GuardLogStatement violations suggest our logging code was written before modern best practices were common. The 119 CloseResource violations in the JPA layer show old-style resource handling that should use try-with-resources. The 38 empty catch blocks are technical debt that could hide real problems. On the bright side, we only have 29 Design violations, which means our architecture is solid.

#### **Refactoring Guidance:** 
Focusing on CloseResource (use try-with-resources), fixing EmptyCatchBlock issues, and adding log level guards.

---

### 5. Code Formatting and Documentation

**Source:** Checkstyle (47,082 total violations)

**Top Checkstyle Issues:**

| Check | Count | Percentage |
|-------|-------|------------|
| IndentationCheck | 37,347 | 79.3% |
| WhitespaceAroundCheck | 2,148 | 4.6% |
| FileTabCharacterCheck | 1,959 | 4.2% |
| WhitespaceAfterCheck | 921 | 2.0% |
| CustomImportOrderCheck | 841 | 1.8% |
| LineLengthCheck | 710 | 1.5% |
| SummaryJavadocCheck | 519 | 1.1% |
| MissingJavadocMethodCheck | 388 | 0.8% |

**Issue Breakdown:**
- **Formatting:** ~43,000 (91%) - indentation, whitespace, tabs
- **Import Order:** ~841 (2%)
- **Javadoc:** ~1,200 (3%)
- **Naming:** ~150 (0.3%)

**Implications:**
- **Code Quality:** Missing documentation (907 Javadoc issues) makes it hard for new developers to learn the code.
- **Maintenance:** Inconsistent formatting (37,347 indentation issues) slows down code reviews because reviewers have to ignore style problems to focus on logic.
- **Performance:** No direct speed impact, but style issues slow down development and cause more merge conflicts.

#### **Insights on the Project's current state:**
Our "formatting issues" (47,082 violations) are mostly from older code. The huge number of IndentationCheck violations (79%) suggests the project was built before modern IDE auto-formatters were widely used. The FileTabCharacter violations (1,959) show different developers used different editor settings. These are cosmetic problems that don't affect how the code runs, but we should fix them for easier maintenance. The relatively low Javadoc violations (907) show we did document our public APIs.

#### **Refactoring Guidance:** 
Setting up IDE auto-formatting with project rules. Adding pre-commit hooks to catch style issues before code is committed.

---

### 6. Depth of Inheritance Tree (DIT)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

**Definition:** DIT measures how deep a class is in the inheritance chain (how many parent classes it has). Deeper hierarchies make code harder to understand and change.

**CodeMR Thresholds:**
- Excellent: DIT ≤ 1
- Medium: DIT ≤ 3
- High: DIT ≤ 10
- Very High: DIT > 10

**Findings:**
The inheritance data covers 33,863 bytes of relationship data. Key points:

- Most classes use moderate inheritance, mainly extending standard frameworks (Struts2 UIAction, JPA implementations)
- UI classes (`ui.struts2.*`) go deeper because the framework requires it
- Domain entities (POJOs) keep inheritance shallow

**Implications:**
- **Code Quality:** Deep inheritance goes against the "composition over inheritance" principle. It creates rigid structures that are hard to extend.
- **Maintenance:** When we change a parent class, all child classes can break. Understanding what a class does requires looking through multiple levels of parents.
- **Performance:** Deep inheritance can slow down method calls slightly, though modern JVMs handle this well.

#### **Insights on the Project's current state:**
Our project uses "moderate inheritance depth", mainly because of framework requirements. The UI layer (`ui.struts2.*`) has deeper inheritance because Struts2 requires it - we can't avoid this when using the framework. Our domain entities (POJOs in `pojos` package) keep inheritance appropriately shallow. We haven't overused inheritance; it's mainly used where frameworks need it rather than as a general code reuse trick. This shows practical design choices that balance framework needs with maintainability.

#### **Refactoring Guidance:** 
Preferring composition over inheritance. Using interfaces and delegation when possible.


---

### 7. Response For a Class (RFC)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

**Definition:** RFC measures the total number of methods that can potentially be executed in response to a message received by an object of a class. It includes methods within the class and methods called by them. High RFC indicates that a class has a broad functional surface area, making it harder to test and maintain.

**CodeMR Thresholds:**
- Low (Excellent): RFC ≤ 50
- Medium-Low: RFC 51–100
- Medium: RFC 101–150
- High: RFC 151–200
- Very High: RFC > 200

| RFC Level | Class Count | % of Total |
|-----------|-------------|------------|
| Low (≤50) | 502 | 99.4% |
| Medium-Low (51–100) | 3 | 0.6% |
| Medium (101–150) | 0 | 0% |
| High (151–200) | 0 | 0% |
| Very High (>200) | 0 | 0% |

**Mean RFC:** 6.94 per class

**Findings:**
- **99.4%** of classes have low RFC (≤50), indicating most classes have a narrow and well-defined functional interface.
- Only **3 classes** in the medium-low range, corresponding to larger manager/servlet classes that executes multiple operations.
- No classes exceed RFC of 100, showing no broad method surfaces.

**Implications:**
- **Software Quality:** Low RFC values correlate with easier unit testing — fewer methods to invoke means fewer test paths.
- **Maintainability:** Classes with low RFC are easier to understand because their behavior is confined to a small set of methods.
- **Performance:** RFC affects memory footprint during testing (mock objects, coverage tracking), though this is rarely a bottleneck.

#### **Insights on the Project's current state:**
Our project has **excellent RFC numbers** with 99.4% of classes staying under the low threshold. The 3 classes in the medium-low range — `RollerAtomHandler` (RFC=77), `WebloggerImpl` (RFC=54), and `PageServlet` (RFC=52) — are all coordination/entry point classes. `RollerAtomHandler` is the highest because it handles the full Atom Publishing Protocol lifecycle. `WebloggerImpl` works as the central service factory, and `PageServlet` manages page rendering. These slightly higher RFC values make sense for these kinds of classes since they naturally need to call methods across many other components.

#### **Refactoring Guidance:** 
The 3 medium-low RFC classes should be examined for possible decomposition.

---

### 8. Average Class Size (LOC per Class)

**Source:** CodeMR

**Definition:** Average Class Size measures the mean lines of code per class across the project. High average class size indicates classes take on too many responsibilities, violating the Single Responsibility Principle (SRP). This metric complements WMC by focusing on physical size rather than logical complexity.

**CodeMR Thresholds for Class LOC:**
- Low (Excellent): LOC ≤ 50
- Medium-Low: LOC 51–300
- Medium: LOC 301–900
- High: LOC 901–1500
- Very High: LOC > 1500

| LOC Level | Class Count | % of Total | Total LOC |
|-----------|-------------|------------|-----------|
| Low (≤50) | 282 | 55.8% | 6,165 |
| Medium-Low (51–300) | 212 | 42.0% | 22,490 |
| Medium (301–900) | 11 | 2.2% | 4,970 |
| High (901–1500) | 0 | 0% | 0 |
| Very High (>1500) | 0 | 0% | 0 |

**Mean LOC per class:** 66.6

**Findings:**
- Over half of classes (**55.8%**) are under 50 LOC, reflecting good decomposition into small, focused units.
- **11 classes** fall in the medium range (301–900 LOC), representing the largest classes in the project. These include `JPAWeblogEntryManagerImpl` (754 LOC), `JPAMediaFileManagerImpl` (499 LOC), and `DatabaseInstaller` (499 LOC).
- No class exceeds 900 LOC, avoiding extremely bloated classes.

**Implications:**
- **Software Quality:** Average class size of 66.6 LOC is reasonable for a Java EE project, though the 11 medium-sized classes concentrate 14.8% of total LOC.
- **Maintainability:** Large classes are harder to navigate, understand, and modify. The largest class (`JPAWeblogEntryManagerImpl` at 754 LOC) is a strong candidate for Extract Class refactoring.
- **Performance:** Large classes may have higher memory footprints and longer compilation times, though this is generally negligible.

#### **Insights on the Project's current state:**
Our project has a **reasonable average class size** of 66.6 LOC, and over half the classes (55.8%) are compact at under 50 lines. The 11 medium-sized classes (301–900 LOC) are where the structural hotspots are. The biggest one, `JPAWeblogEntryManagerImpl` (754 LOC), packs in entry CRUD, comment handling, tag operations, and query building — clearly doing too many things. Other larger classes like `DatabaseInstaller` (499 LOC) and `JPAMediaFileManagerImpl` (499 LOC) also stand out. The domain entities `WeblogEntry` (445 LOC) and `Weblog` (436 LOC) are large mainly because they have lots of fields and getters/setters, which is normal for JPA entities. The JPA manager classes, on the other hand, are good candidates for splitting into smaller services.

#### **Refactoring Guidance:** 
Targeting the 11 medium-sized classes for decomposition, starting with `JPAWeblogEntryManagerImpl` (754 LOC) which can be split into separate comment, tag, and query management services.


