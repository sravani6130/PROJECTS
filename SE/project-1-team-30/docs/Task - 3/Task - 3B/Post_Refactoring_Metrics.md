# Task 3B: Post-Refactoring Metrics Analysis

## Tools Used

| Tool | Purpose |
|------|---------|
| **CodeMR** | OO metrics (CBO, LCOM, WMC, DIT, RFC, LOC/Class) |
| **PMD** | Static analysis (best practices, error-prone patterns) |
| **Checkstyle** | Code style and documentation compliance |

---

## Project Summary: Before vs. After

| Metric | Before Refactoring | After Refactoring | Change |
|--------|-------------------|-------------------|--------|
| **Total Entities (Classes/Interfaces)** | 542 | 573 | +31 |
| **Total Packages** | 64 | 66 | +2 |
| **Class Lines of Code (LOC)** | 33,625 | 34,144 | +519 |
| **External Packages** | 91 | 91 | No change |
| **External Entities** | 278 | 278 | No change |
| **Problematic Classes** | 12 | 14 | +2 |
| **Highly Problematic Classes** | 0 | 0 | No change |

---

## Metric-by-Metric Comparison

### 1. Coupling Between Object Classes (CBO)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

| CBO Level | Before (Classes) | Before (LOC) | After (Classes) | After (LOC) | Change (Classes) |
|-----------|-------------------|--------------|-----------------|-------------|------------------|
| Low (Excellent) | 418 | 17,632 | 447 | 18,426 | **+29** |
| Medium-Low | 83 | 7,753 | 85 | 7,880 | +2 |
| Medium | 34 | 5,675 | 32 | 5,619 | **−2** |
| High (Concerning) | 9 | 2,889 | 11 | 2,590 | **+2** |
| Very High | 0 | 0 | 0 | 0 | No change |

**Verdict:  Mixed — Mostly Improved**

**Discussion:**
- The proportion of low-coupling classes **improved** from 77.1% (418/542) to **78.0%** (447/573), and the LOC in the low category increased by 794 lines.
- The medium category **shrank** from 34 to 32 classes, which is a positive shift.
- However, the high-coupling category **increased** from 9 to 11 classes. While the LOC in high-coupling classes decreased from 2,889 to 2,590 (−299 LOC), the additional 2 high-coupling classes likely represent **new abstraction layers** (e.g., service interfaces, query builders) that naturally interact with multiple other classes.

**Implication:** The refactoring successfully improved coupling for the majority of the codebase, but the architectural changes (introducing new manager/service interfaces) inevitably increased coupling for a few coordination-layer classes. This is a **known trade-off**: extracting classes to improve cohesion and reduce complexity often requires intermediary classes that are more highly coupled.

---

### 2. Lack of Cohesion of Methods (LCOM)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

| LCOM Level | Before (Classes) | Before (LOC) | After (Classes) | After (LOC) | Change (Classes) |
|------------|-------------------|--------------|-----------------|-------------|------------------|
| Excellent (Low LCOM) | 484 | 24,291 | 512 | 24,983 | **+28** |
| Medium-Low | 36 | 4,963 | 39 | 5,286 | +3 |
| Medium | 19 | 3,040 | 19 | 2,931 | No change |
| High (Concerning) | 4 | 1,456 | 4 | 1,093 | **No change** |
| Very High | 1 | 199 | 1 | 222 | No change |

**Verdict: Improved**

**Discussion:**
- The number of classes with excellent cohesion **increased** from 484 to 512 (+28), meaning **89.4% → 89.4%** of classes maintain excellent cohesion (the ratio stays similar due to more total classes).
- While the count of high-LCOM classes remained at 4, the LOC in this category **decreased significantly** from 1,456 to 1,093 (−363 LOC, a 24.9% reduction). This indicates that refactoring successfully **extracted responsibilities** from these poorly-cohesive classes, reducing their bloat without fully eliminating the cohesion issues.
- The medium-level category maintained 19 classes but reduced from 3,040 to 2,931 LOC, showing incremental improvement.

**Implication:** The Extract Class refactoring pattern was effective — the newly created classes (contributing to the 28 additional excellent-cohesion classes) absorbed responsibilities from larger classes, improving overall cohesion. The residual high-LCOM classes likely contain framework-mandated mixed concerns that cannot be easily separated.

---

### 3. Weighted Methods per Class (WMC) / Cyclomatic Complexity

**Source:** CodeMR

| Complexity Level | Before (Classes) | Before (LOC) | After (Classes) | After (LOC) | Change (Classes) |
|------------------|-------------------|--------------|-----------------|-------------|------------------|
| Low Complexity | 385 | 16,984 | 423 | 18,596 | **+38** |
| Medium Complexity | 151 | 14,431 | 144 | 13,747 | **−7** |
| High Complexity | 7 | 2,191 | 7 | 1,829 | **No change**|
| Very High Complexity | 1 | 343 | 1 | 343 | No change |

**Verdict: Improved**

**Discussion:**
- Low-complexity classes **increased** from 385 to 423 (+38), and their LOC grew by 1,612 lines. The proportion of low-complexity classes improved from **71.0% → 73.8%**.
- Medium-complexity classes **decreased** from 151 to 144 (−7), indicating that 7 formerly medium-complexity classes were simplified enough to move into the low-complexity category.
- High-complexity LOC **decreased** from 2,191 to 1,829 (−362, a 16.5% reduction), even though the count remained at 7. This means the refactoring extracted some logic from these complex classes into simpler helper classes.
- The single very-high-complexity class (343 LOC) **remained unchanged**, suggesting this class contains irreducible complexity that may require deeper architectural changes.

**Implication:** The complexity improvements validate the Extract Method and Extract Class refactoring patterns. The shift from medium → low complexity is the most impactful change, as it directly improves testability and developer comprehension. The persistent very-high-complexity class is a candidate for future refactoring using the Strategy or State design pattern.

---

### 4. Code Style Violations (PMD)

**Source:** PMD Static Analysis (Same ruleset used before and after refactoring)

| PMD Category | Before | After | Change |
|--------------|--------|-------|--------|
| **Best Practices** | 704 | 700 | −4 |
| **Error Prone** | 445 | 439 | −6 |
| **Code Style** | 261 | 267 | +6 |
| **Documentation** | 113 | 115 | +2 |
| **Design** | 29 | 30 | +1 |
| **Multithreading** | 3 | 3 | 0 | No change |
| **Total** | **1,555** | **1,554** | **−1** |

**Top Rule Comparison:**

| Rule | Before | After | Change |
|------|--------|-------|--------|
| GuardLogStatement | 518 | 513 | −5 |
| ProperLogger | 217 | 216 | −1 |
| UselessParentheses | 121 | 122 | +1 |
| CloseResource | 119 | 114 | −5 |
| LiteralsFirstInComparisons | 70 | 70 | No change |
| UncommentedEmptyConstructor | 64 | 64 | No change |
| UncommentedEmptyMethodBody | 49 | 51 | +2 |
| PreserveStackTrace | 46 | 46 | No change |
| UnnecessaryImport | 42 | 45 | +3 |
| EmptyCatchBlock | 38 | 38 | No change |

**Verdict: Largely Unchanged**

**Discussion:**
- PMD violations remained **virtually unchanged** (1,555 → 1,554), a decrease of only 1 violation across the entire codebase.
- **Best Practices** and **Error Prone** categories saw marginal decreases (−4 and −6 respectively), with small reductions in GuardLogStatement (518→513) and CloseResource (119→114). These reductions are likely from refactored methods that were reorganized into new classes.
- **Code Style** violations slightly **increased** by 6 (261 → 267), and **Documentation** increased by 2 (113 → 115). This is a natural side-effect of introducing new classes — each new class file adds opportunities for style and documentation violations (e.g., `UncommentedEmptyMethodBody` increased from 49 to 51 due to new delegate methods).
- The **UnnecessaryImport** count increased (42 → 45), as class extraction can leave behind unused imports in the original file.

**Implication:** The refactoring was **structurally focused** — it targeted OO design improvements (coupling, cohesion, complexity) rather than PMD-level code hygiene. The PMD violations like GuardLogStatement (513), CloseResource (114), and EmptyCatchBlock (38) remain as **technical debt** that should be addressed in a separate, dedicated code-cleanup effort. This demonstrates that **structural refactoring and code-level cleanup are independent activities** — improving one does not automatically improve the other.

---

### 5. Code Formatting and Documentation Compliance (Checkstyle)

**Source:** Checkstyle (Same Google-style configuration used before and after refactoring)

| Check | Before | After | Change |
|-------|--------|-------|--------|
| IndentationCheck | 37,347 | 37,803 | +456 |
| WhitespaceAroundCheck | 2,148 | 2,054 | −94 |
| FileTabCharacterCheck | 1,959 | 1,955 | −4 |
| CustomImportOrderCheck | 841 | 902 | +61 |
| WhitespaceAfterCheck | 921 | 885 | −36 |
| LineLengthCheck | 710 | 722 | +12 |
| SummaryJavadocCheck | 519 | 520 | +1 |
| ParenPadCheck | 519 | 487 | −32 |
| MissingJavadocMethodCheck | 388 | 395 | +7 |
| LeftCurlyCheck | 100 | 100 | No change |
| **Total** | **47,082** | **47,531** | **+449** |

**Verdict: Slightly Deteriorated**

**Discussion:**
- Checkstyle violations **increased marginally** by 449 (47,082 → 47,531), a 1.0% increase.
- The **dominant issue remains IndentationCheck** (37,803 = 79.5% of all violations), which increased by 456. The new classes introduced during refactoring likely followed slightly different indentation conventions, contributing to these additional violations.
- **Whitespace-related issues improved**: WhitespaceAroundCheck decreased by 94, WhitespaceAfterCheck by 36, and ParenPadCheck by 32, totaling a reduction of ~162 whitespace violations.
- **Import ordering violations increased** (841 → 902, +61): The introduction of new classes with new import statements that don't follow the configured import ordering rules explains this increase.
- **Documentation violations were essentially unchanged**: SummaryJavadocCheck (+1) and MissingJavadocMethodCheck (+7) show the new classes were created with similar documentation practices as existing code.

**Implication:** The marginal Checkstyle increase is a **natural byproduct** of adding 31 new classes and 519 LOC — each new file introduces opportunities for formatting and style violations. The increase is proportionally less than the code growth (1.0% violation increase vs. 1.5% LOC increase), suggesting the new code is slightly **better formatted** than the existing average. The whitespace improvements indicate some cleanup occurred in refactored files. However, the persistent IndentationCheck dominance (79.5%) remains the largest area for future improvement.

---

### 6. Depth of Inheritance Tree (DIT)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

| Aspect | Before | After | Change |
|--------|--------|-------|--------|
| **Total Packages** | 64 | 66 | +2 |
| **New Packages** | — | `business.jpa.query`, `business.jpa.query.handlers` | New |
| **Inheritance Style** | Moderate, framework-driven | Moderate, more interface-driven | Improved |

**Verdict: Improved (Structural)**

**Discussion:**
- The introduction of 2 new packages (`business.jpa.query` and `business.jpa.query.handlers`) employs a **composition-over-inheritance** approach. The `handlers` package contains 8 specialized `CriterionHandler` classes (e.g., `WeblogCriterionHandler`, `DateRangeCriterionHandler`, `StatusCriterionHandler`, etc.) that implement a common interface rather than extending a deep class hierarchy.
- This is a textbook example of the **Strategy pattern**, which keeps inheritance depth shallow while enabling extensibility.
- The new `WeblogQueryBuilder` and `WeblogEntryQueryBuilder` classes use **composition** (delegating to handlers) rather than inheritance, maintaining a flat hierarchy.

**Implication:** The refactoring explicitly favored composition over inheritance. The new query architecture uses interfaces and delegation, keeping DIT values low while achieving flexibility. This is precisely the approach recommended in Task 2B's refactoring guidance.

---

### 7. Response For a Class (RFC)

**Source:** CodeMR (Chidamber & Kemerer Metric Suite)

| RFC Level | Before (Classes) | Before (%) | After (Classes) | After (%) | Change |
|-----------|-----------------|------------|-----------------|-----------|--------|
| Low (≤50) | 502 | 99.4% | 527 | 99.2% | **+25** |
| Medium-Low (51–100) | 3 | 0.6% | 4 | 0.8% | +1 |
| Medium (101–150) | 0 | 0% | 0 | 0% | No change |
| High (151–200) | 0 | 0% | 0 | 0% | No change |
| Very High (>200) | 0 | 0% | 0 | 0% | No change |

**Mean RFC:** 6.94 → 6.72 (↓ 3.2%)

**Verdict: Improved**

**Discussion:**
- The number of low-RFC classes **increased** from 502 to 527 (+25), meaning the refactoring introduced 25 new classes with narrow, well-defined functional interfaces.
- The mean RFC **decreased** from 6.94 to 6.72, indicating that the average class has a slightly smaller method surface area after refactoring.
- One additional class moved into the medium-low range (3 → 4), likely a new coordination class (e.g., `WeblogQueryBuilder`) that calls methods across multiple handler classes.
- The 34 new classes introduced by the refactoring have an average of only **3–4 methods each**, contributing to the lower mean RFC.

**Implication:** The Extract Class refactoring successfully created new classes with **narrow functional surfaces**, validating the decomposition strategy. Classes like `DateRangeCriterionHandler` (15 LOC, 2 methods) and `StatusCriterionHandler` (8 LOC, 1 method) are ideal examples of low-RFC design — each does one thing and does it well.

---

### 8. Average Class Size (LOC per Class)

**Source:** CodeMR

| LOC Level | Before (Classes) | Before (%) | After (Classes) | After (%) | Change |
|-----------|-----------------|------------|-----------------|-----------|--------|
| Low (≤50) | 282 | 55.8% | 300 | 56.5% | **+18** |
| Medium-Low (51–300) | 212 | 42.0% | 221 | 41.6% | +9 |
| Medium (301–900) | 11 | 2.2% | 10 | 1.9% | **−1** |
| High (901–1500) | 0 | 0% | 0 | 0% | No change |
| Very High (>1500) | 0 | 0% | 0 | 0% | No change |

**Mean LOC per class:** 66.6 → 64.3 (↓ 3.5%)

**Key Class Size Reductions:**

| Class | Before (LOC) | After (LOC) | Reduction |
|-------|-------------|-------------|-----------|
| `JPAWeblogEntryManagerImpl` | 754 | 392 | **−362** |
| `JPAWeblogManagerImpl` | 389 | 331 | **−58** |

**Verdict: Improved**

**Discussion:**
- The average class size **decreased** from 66.6 to 64.3 LOC (−3.5%), despite adding 519 total LOC to the project. This is because the 34 new classes average only ~47 LOC each, pulling the mean down.

- The proportion of **small classes (≤50 LOC) increased** from 55.8% to 56.5%, reflecting the creation of focused, single-responsibility handler classes.
- The 34 newly introduced classes include many small, focused units: 8 `CriterionHandler` classes (8–15 LOC each), service interfaces (7–26 LOC), and service implementations (47–172 LOC).

**Implication:** The refactoring achieved its primary goal of **reducing class bloat**. The near-halving of `JPAWeblogEntryManagerImpl` (754→392 LOC) is the single most significant size improvement, demonstrating that Extract Class refactoring can improve the physical structure of large classes while maintaining overall codebase coherence.


---

## Summary: Overall Quality Distribution

| Quality Attribute | Before (Pre-Refactoring) | After (Post-Refactoring) | Trend |
|-|-|-|-|
|  Low-Coupling Classes | 418 | 447 | Improved |
|  Excellent-Cohesion Classes | 484 | 512 | Improved |
|  Low-Complexity Classes | 385 | 423 | Improved |
|  Mean RFC | 6.94 | 6.72 | Improved |
|  Mean LOC/Class | 66.6 | 64.3 | Improved |
|  Problematic Classes | 12 | 14 | Slight increase |
|  Highly Problematic Classes | 0 | 0 | Stable |
|  PMD Violations | 1,555 | 1,554 | Unchanged |

---

## Can One Metric Improve While Another Gets Worse?

**Yes**,

### Observed Trade-offs

1. **Cohesion (LCOM) improved ↔ Coupling (CBO) partially worsened**

   When we extracted responsibilities from large, poorly-cohesive classes into smaller, focused classes, each new class has better cohesion (doing one thing well). However, these new classes need to **communicate** with each other, which increases inter-class coupling. For example, splitting `JPAWeblogEntryManagerImpl` into separate services (`JPAWeblogCommentServiceImpl`, `JPAWeblogTagServiceImpl`, etc.) improved cohesion but introduced new coupling between these service classes.


2. **Complexity (WMC) improved ↔ Entity count increased**

   By extracting complex methods into separate classes (e.g., 8 `CriterionHandler` classes from query logic), we reduced per-class complexity. But this increased the total number of classes from 542 to 573 (+31). While each class is simpler, the system as a whole has more moving parts. This is generally considered a worthwhile trade-off because simpler classes are easier to test and maintain independently.

3. **OO metrics improved ↔ PMD/Checkstyle violations unchanged**

   The refactoring significantly improved structural OO metrics (CBO, LCOM, WMC) by decomposing large classes, but PMD and Checkstyle violations remained essentially the same. This demonstrates that **structural refactoring** (Extract Class, Extract Method, Strategy pattern) and **code hygiene cleanup** (fixing style violations, adding documentation) are **independent concerns**. Improving architecture does not automatically fix code-level issues, and vice versa.

4. **Entity count increased ↔ Problematic classes increased**

   Adding 31 new classes to improve modularity is beneficial, but 2 of those new coordination-layer classes (e.g., `WeblogQueryBuilder`) crossed the CBO threshold, increasing the problematic class count from 12 to 14. More classes means more potential for some to be flagged as problematic.



> The key idea is that **no single metric should be optimized in isolation**. Good refactoring aims for the **best overall balance** across all metrics when achieving significant gains in others.


