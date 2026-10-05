**Варианты названия для промпта (файла или шаблона):**

* `Opus_XNU_Fish_Auditor`
* `macOS_CLI_Architecture_Audit`
* `Deep_Refactoring_Plan_Prompt`
* `Prompt: macOS Shell Anti-Pattern Audit`

**Английская версия промпта:**

> **Role:** Senior Systems Engineer (macOS XNU architecture, `fish` shell, low-level optimization).
> **Task:** Conduct an architectural audit of my `fish` configuration based on the attached deep research dump and formulate a step-by-step refactoring plan.
> **Execution Algorithm (strictly in order):**
> 1. Study the provided research dump ("CLI & macOS Optimization Anti-Patterns").
> 2. Analyze my attached `fish` configuration.
> 3. Identify **all** occurrences of the described anti-patterns within my configuration.
> 4. Generate a comprehensive refactoring plan. **Do not write the actual refactored code**; I only need the architectural roadmap and task list.
> 
> 
> **Output Format (strictly adhere):**
> **Part 1. Architectural Overview (Top Section)**
> * A complete list of all subject domains covered in the research.
> * A concise extraction of only the critically important anti-patterns (bottlenecks) from each domain.
> 
> 
> **Part 2. Audit Results**
> * Point out the exact locations in my config (specific files/functions) where the anti-patterns from Part 1 manifest.
> * Explain exactly why each identified instance is problematic at the OS level (e.g., unnecessary `fork`, blocking I/O, IPC overhead).
> 
> 
> **Part 3. Refactoring Plan**
> * A step-by-step, actionable task list designed to eliminate the identified system bottlenecks.
> 
> 
> **Inputs:**
> [@.meta/research/anti_patterns_macOS.md]
> [...]
