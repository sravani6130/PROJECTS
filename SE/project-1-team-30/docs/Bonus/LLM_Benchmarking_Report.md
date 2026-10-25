# Bonus Task: Benchmarking LLMs on Apache Roller

## 1. Summary of Results

Overall, the **Agent-based workflows were much better** than the chat-only workflows. Giving the models access to read the actual `JPA...Impl` files made a huge difference.

Here is a breakdown of how they performed:

| Model & Mode | Smell Identification | Refactoring Quality | Code Compliability |
| :--- | :--- | :--- | :--- |
| **Claude 3.5 Sonnet (Agent)** | **Excellent** (Matched our findings exactly) | **High** (Complete Service separation) | **High** (Valid imports & Guice setup) |
| **Gemini 3 Pro (Agent)** | **Good** (Found similar issues) | **Good** (Focused on interfaces) | **High** (Valid Java) |
| **Claude 3.5 Sonnet (Ask)** | **Low** (Guessed incorrectly) | **Medium** (Good theory, wrong context) | **Low** (Wrong package structure) |
| **Gemini 3 Pro (Ask)** | **Low** (Missed the main architectural issue) | **Medium** (Good local logic fix) | **Medium** (Valid logic, context vague) |

---

## 2. Comparison: Smell Identification

### Manual Baseline (Ground Truth)
During our manual analysis of the project, the biggest issue We found was **"Insufficient Modularization"** (or a "God Class" problem). Specifically, classes like `JPAWeblogEntryManagerImpl` were doing too much—handling entries, categories, comments, and media all in one place.

### How the LLMs Performed

#### **Claude 3.5 Sonnet (Agent Mode) :**
This was the most accurate model. It correctly flagged `JPAWeblogEntryManagerImpl` as a "God Class" that violated the Single Responsibility Principle. It specifically pointed out the exact same mixed responsibilities I found—listing "Entry Management," "Category Management," and "Comment Management" as distinct concerns that shouldn't be in one file.

#### **Gemini 3 Pro (Agent Mode):**
Gemini did a good job here too. It identified the `WeblogEntryManager` ecosystem as a "Service Locator" or "God Class" anti-pattern. Ideally, I would have liked it to focus more on the implementation class (`JPAWeblogEntryManagerImpl`) rather than just the interface, but its analysis was largely correct and aligned with our own.

#### **The "Ask" Models (Non-Agentic):**

Both models struggled significantly when they couldn't read the files.
- **Claude (Ask)** guessed there was a God Class based on test filenames but pointed to the `planet.business` package (which exists, but isn't where the main code is) instead of the core `weblogger` package where the actual problem lies. It also assumed a structure that implies a different architecture than what is really there.
  
- **Gemini (Ask)** focused on very small, localized issues like "Primitive Obsession" in a specific file upload check. While technically a smell, it missed the larger architectural problems entirely.

**Conclusion on Identification:** The Agent models successfully replicated our manual findings. The standard chat models mostly guessed or focused on trivia.

---

## 3. Comparison: Code Quality and Compliability

We also looked at the refactoring code each model proposed to see if it was actually usable.

### **Claude 3.5 Sonnet (Agent Mode):**

Claude provided the most complete solution. It proposed splitting the massive `JPAWeblogEntryManagerImpl` into three distinct service classes (`WeblogEntryService`, `WeblogCategoryService`, `WeblogCommentService`).

- **Quality:** The code felt natural for the project. It correctly used the existing `@Inject` and `@Singleton` annotations.

- **Compliability:** It imported the correct `pojos` and used valid JPA method calls (`strategy.getNamedQuery`). We could likely copy-paste this code into the IDE with very few errors.

### **Gemini 3 Pro (Agent Mode):**

Gemini focused on refactoring the **Interfaces** first.

- **Quality:** This is a good architectural step. It defined clean interfaces for `WeblogEntryService`, etc.
  
- **Compliability:** The Java code for the interfaces was perfect. However, it didn't provide as much implementation logic as Claude, meaning We'd have to write more code ourself to get it working.

### **Claude 3.5 Sonnet (Ask Mode):**

This model tried to rewrite the application using a "business logic first" style.

- **Quality:** The code looked great and used new Java features (like Instant and records).
  
- **Compliability:** **Poor**. It used a `domain.model` package (which isn't there) instead of using the existing `pojos` package. Trying to use this code would break the entire application because it doesn't fit the existing architecture at all.

### **Gemini 3 Pro (Ask Mode):**

This model fixed a specific method (`checkFileType`) by creating small helper classes to handle the rules.

- **Quality:** The logic was good and well-structured.
  
- **Compliability:** It was valid Java code, but because it only fixed one tiny method, it didn't address the main complexity issues of the project.

---

## 4. Final Verdict

After comparing all four outputs, **Claude 3.5 Sonnet (Agent)** performed the best.

It was the only model that:
1.  Matched our manual findings almost exactly (identifying the specific "God Class").
   
2.  Provided a solution that was ready to use directly and fit well with the rest of the project.

