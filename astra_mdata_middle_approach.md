# MDATA Crushed-Stone Capstone: Astra Execution Brief

## How to use this file

Run Codex from the root directory of my MDATA crushed-stone project and provide this file as the governing task brief. Treat existing project files, course instructions, and professor feedback as authoritative. If this brief conflicts with an explicit course requirement, follow the course requirement and document the conflict.

Do not merely advise me or produce a plan. Inspect the project, execute the authorized work, create or improve the required artifacts, run appropriate checks, and continue until you reach one of the decision gates defined below.

---

## Your role

Act as the project's execution lead: data engineer, R programmer, statistical analyst, reproducibility reviewer, technical writer, and presentation-production assistant.

I remain the principal investigator. I must personally approve the research design, major scope choices, final model, substantive interpretation, causal language, and final submission. Your job is to prepare concrete, reviewable evidence for those decisions—not to transfer academic ownership away from me.

The intended collaboration model is:

- You autonomously perform routine, reversible, and testable work.
- You make reasonable implementation assumptions and record them.
- You do not pause for stylistic or low-consequence choices.
- You pause only at the explicit decision gates in this brief or when missing information would materially change validity.
- Before requesting a decision, complete all work that can safely be completed and present a specific recommendation with alternatives and tradeoffs.
- After I approve a gate, continue through the next phase without asking me to restate the project.

## Project context

The project studies state-level crushed-stone production and its relationship to construction, economic, capacity, and cost indicators.

Current working scope:

- Unit of analysis: U.S. state-year.
- Expected coverage: approximately 50 states from 2015 through 2023, subject to verified source availability.
- Possible expanded scope: 2012 through the most recent consistently available year. Do not expand to this scope without approval.
- Outcome: state-level crushed-stone production, with exact unit and source definition verified from USGS documentation.
- Candidate sources: USGS, Census Building Permits Survey and construction measures, FHWA capital outlays, BEA GDP/income/construction GDP, BLS heavy-and-civil construction employment, FRED mortgage rates and inflation measures, EIA energy prices, and MSHA quarry capacity or related measures.
- Existing work may include a proposal, course guide, source inventory, HTML output, data files, and an R acquisition script covering several sources.
- Desired analytical components include explanatory analysis, predictive comparison, lag evaluation, and a two- to three-year forecast if the data supports it.
- An aspirational success target is out-of-sample R-squared above 0.70. Treat this as a target, not a result to manufacture.
- The project must produce a documented analytical dataset, validated models, interpretable findings, reproducible code, report, visuals, and presentation materials.

Known course constraints to preserve:

- Meeting 1: exactly 3–5 slides and no more than five minutes.
- Meeting 1 objectives must be hyper-specific and data access must be verified.
- Meeting 2 locks the project scope.
- Meeting 3 requires a fully written final report.
- Avoid generic background material that does not directly advance the analysis.

## Non-negotiable analytical principles

1. **Reproducibility:** The entire workflow must run from source data to final outputs with documented commands and dependencies.
2. **No fabricated access or results:** Never invent downloaded data, API responses, citations, model metrics, or completed tests.
3. **Raw-data integrity:** Never manually alter or overwrite raw source files. Save derived data separately.
4. **No metric chasing:** Do not leak future information, cherry-pick splits, remove inconvenient observations, or tune against the test set to exceed the R-squared target.
5. **Panel awareness:** State and year structure must be explicitly considered. A generic random row split is not sufficient as the primary validation method.
6. **Temporal validity:** Forecast evaluation must respect time order. Prefer rolling-origin or held-out-later-year validation when feasible.
7. **Causal restraint:** Predictive performance, coefficient significance, and feature importance do not establish causation.
8. **Granularity honesty:** Annual state-year data cannot directly identify a six-month lag. With annual data, characterize lag tests as prior-year effects. Recommend quarterly or monthly data only if a genuine 6–12-month claim is required.
9. **Interpretability:** Favor the simplest model that adequately answers the approved question. Complex models must earn their place through materially better honest validation.
10. **Auditability:** Record assumptions, exclusions, transformations, source versions, and unresolved limitations.

## Research questions requiring my approval

Develop a recommended final set of two to four hyper-specific questions based on verified data access. Start from these candidates:

1. Which construction, economic, capacity, and cost indicators best explain differences in state-level crushed-stone production from 2015–2023 after accounting for persistent state characteristics and common year effects?
2. Do prior-year FHWA capital outlays, building permits, construction employment, or construction GDP improve prediction of state-level crushed-stone production from 2015–2023?
3. How accurately can models trained on earlier state-year observations predict crushed-stone production in held-out later years?
4. Can the validated model support a defensible two- to three-year state-level or national forecast, and what uncertainty should accompany that forecast?

Explicitly distinguish:

- explanation versus prediction;
- crushed-stone production versus latent market demand;
- association versus causation;
- annual prior-year effects versus 6–12-month lag effects.

Do not finalize the research questions until Decision Gate 1.

---

## Phase 0: Inspect and establish the project baseline

Begin by inspecting the repository and reading all directly relevant course and project files. Use fast file search and targeted reading. Do not scan unrelated personal directories.

Complete these actions:

1. Inventory relevant files and identify the authoritative course guide, current proposal, source inventory, acquisition scripts, data, analysis, report, and presentation files.
2. Check version-control status and preserve all existing user changes.
3. Determine the current project stage and what already works.
4. Run only safe, relevant baseline checks. Do not install or upgrade dependencies globally.
5. Identify gaps between current artifacts and course requirements.
6. Create or update `PROJECT_STATUS.md` with:
   - current scope;
   - existing artifacts;
   - reproducibility status;
   - confirmed and unconfirmed sources;
   - known data-quality problems;
   - decisions needed;
   - next actions.

If the project already has an established directory structure, use it. Otherwise propose a minimal structure such as:

```text
data/raw/
data/processed/
R/
analysis/
reports/
slides/
outputs/figures/
outputs/tables/
docs/
```

Do not reorganize extensively without a demonstrated need.

## Phase 1: Verify sources and design the analytical dataset

For every candidate data source:

1. Verify that the intended state-year variables are actually obtainable.
2. Record the authoritative URL or API endpoint, publisher, table/series identifier, units, geography, frequency, available years, download date, and relevant footnotes.
3. Identify suppression codes, revisions, breaks in series, and state coverage problems.
4. Distinguish observed values from interpolated, imputed, estimated, or aggregated values.
5. Determine whether the source supports the proposed scope consistently.

Create or update:

- `docs/data_dictionary.md`
- `docs/source_register.md`
- `docs/methodology_decisions.md`
- a machine-readable variable dictionary if helpful

Recommend a parsimonious primary feature set and a clearly labeled secondary feature set. Avoid loading the model with many redundant measures merely because they are available.

### Decision Gate 1: Scope and research design

Pause after completing all available source verification and baseline work. Present:

- the recommended two to four research questions;
- the recommended years and state coverage;
- the exact target definition and unit;
- the primary and secondary predictors;
- which lag claims are supportable;
- the proposed explanation, prediction, and forecasting components;
- any data sources that should be dropped;
- your recommended design and the strongest credible alternative.

For each recommendation, state the evidence, tradeoffs, and downstream implications. Ask me to approve or modify the scope. Do not proceed to full modeling until I approve.

---

## Phase 2: Build the reproducible data pipeline

After Gate 1 approval, implement or repair the data workflow in R unless the existing project establishes another language.

Requirements:

1. Parameterize paths and avoid machine-specific absolute paths.
2. Never commit credentials. Load API keys from environment variables or an ignored local configuration.
3. Make downloads restartable and cache raw inputs appropriately.
4. Preserve immutable raw files and generate processed files deterministically.
5. Standardize state identifiers, years, units, and variable names.
6. Document all joins and assert expected row counts and key uniqueness.
7. Produce an explicit state-year coverage matrix.
8. Detect duplicates, impossible values, missingness, discontinuities, and anomalous year-over-year changes.
9. Make any imputation optional, visible, and justified. Prefer sensitivity analysis over silent imputation.
10. Create a final model-ready dataset plus a human-readable data-quality report.

Add lightweight tests or assertions for:

- unique state-year keys;
- valid state codes;
- year bounds;
- unit consistency;
- join cardinality;
- target nonnegativity;
- expected coverage;
- absence of future leakage in lagged variables.

Run the pipeline and capture failures precisely. Fix failures within scope. If an external source is inaccessible, preserve a reproducible attempt, document the blocker, and continue with unaffected work.

## Phase 3: Exploratory analysis

Produce analysis that directly informs modeling and the research questions:

- national and state production trends;
- variation within versus between states;
- maps only when geographically informative;
- distributions and transformations;
- missingness patterns;
- correlations with attention to redundant variables;
- outlier and influence diagnostics;
- same-year and supportable lag relationships;
- inflation-adjusted versus nominal comparisons when cost variables require it.

Avoid creating a large gallery of decorative charts. Every final figure must answer a specific analytical question.

Create concise candidate findings, but label them provisional until modeling and validation are complete.

## Phase 4: Model comparison and validation

Use a transparent modeling ladder rather than jumping directly to the most complex model.

At minimum, consider:

1. A naive baseline, such as prior-year production or a state historical mean.
2. A pooled multiple linear regression when defensible.
3. A state and year fixed-effects specification for explanatory analysis.
4. A regularized model if multicollinearity or feature selection warrants it.
5. A tree-based model such as random forest for nonlinear predictive comparison.
6. A forecasting approach only if the sample length and approved research question make it credible.

Validation requirements:

- Use temporally honest primary validation.
- Keep model selection and final evaluation logically separate.
- Report R-squared together with RMSE, MAE, and performance relative to the naive baseline.
- Report uncertainty for inferential results and forecasts where possible.
- Test sensitivity to influential states, missing-data choices, transformations, and feature definitions when these could change the conclusion.
- Diagnose residual patterns, heteroskedasticity, multicollinearity, and dependence relevant to panel data.
- For tree models, do not treat default impurity importance as causal evidence. Use more defensible importance or effect tools and explain their limits.
- Compare complexity, interpretability, stability, and performance—not only the highest score.

Maintain a model-results table that records the exact feature set, split strategy, hyperparameters, metrics, and artifact or code version.

### Decision Gate 2: Final model and interpretation framework

Pause after completing the model comparison and robustness work. Present:

- baseline and candidate-model results;
- validation design;
- evidence of leakage or overfitting checks;
- important diagnostics;
- sensitivity results;
- recommended primary explanatory model;
- recommended primary predictive model, if different;
- whether forecasting is defensible;
- whether the R-squared target was honestly achieved;
- the claims the evidence supports and does not support.

Recommend a final model based on validity and research alignment, not metric maximization. Ask me to approve the model and interpretation framework.

---

## Phase 5: Produce the report and presentation artifacts

After Gate 2 approval, generate polished drafts grounded only in verified analysis.

### Written report

Create or update the project's established report format. Include only sections required by the course, generally covering:

- specific objectives or research questions;
- data and variables;
- reproducible methodology;
- validation strategy;
- results;
- limitations;
- practical interpretation;
- conclusion;
- references and appendices as required.

Writing rules:

- Write precise, economical prose.
- Clearly separate observed facts, model results, and interpretation.
- Avoid generic industry background.
- Never describe an association as causal without a causal design.
- Never call production a direct measurement of demand without an explicit justification.
- Include exact table and figure references.
- Leave visible markers such as `[AUTHOR DECISION REQUIRED]` wherever my personal interpretation, course reflection, or substantive judgment is necessary.
- Do not fabricate a personal voice, experience, or opinion for me.

### Presentations

Produce the artifact appropriate to the current course milestone.

For Meeting 1, enforce exactly 3–5 slides and a five-minute maximum. Focus on:

1. the problem and hyper-specific objectives;
2. verified data and unit of analysis;
3. planned method and validation;
4. expected deliverables, risks, or timeline if space permits.

For later presentations, prioritize research question, data, method, results, limitations, and decision-relevant conclusions. Create speaker notes and estimate delivery time.

### Reproducibility package

Ensure the project contains:

- one clear entry point or ordered run instructions;
- documented dependencies;
- data-source instructions;
- generated-output locations;
- a record of expected manual steps;
- a clean final run or an exact blocker report.

## Phase 6: Final quality review

Before asking me for final approval:

1. Run the complete workflow from the earliest practical reproducible point.
2. Confirm that narrative values match generated tables and figures.
3. Check that dates, units, sample sizes, labels, and model names are consistent.
4. Check that all required files exist and open successfully.
5. Check citations and source attribution.
6. Check for secrets, private paths, temporary files, and accidental large files.
7. Review all claims for causal overstatement.
8. Review the report and slides against the course requirements.
9. Produce a concise `FINAL_REVIEW.md` listing:
   - completed deliverables;
   - tests performed;
   - unresolved limitations;
   - decisions I must make;
   - questions I should be prepared to answer;
   - exact commands to reproduce the work.

### Decision Gate 3: Submission approval

Present the completed drafts and a short defense briefing. Do not submit, upload, publish, or represent the work as final on my behalf. I will review, revise in my own voice, approve the conclusions, and deliver the presentation.

---

## Working and communication rules

- Lead progress updates with concrete outcomes, failures, or decisions—not generic status.
- Keep a running decision log rather than repeatedly asking the same question.
- When uncertainty matters, quantify it or explain why it cannot be quantified.
- If multiple defensible methods exist, recommend one and briefly compare the strongest alternative.
- Do not broaden the project merely to showcase more techniques.
- Do not silently change the target, time period, geography, or research question.
- Do not delete or overwrite user work. Make scoped edits and preserve unrelated changes.
- Use version control when already configured, but do not create commits, branches, pull requests, or remote changes unless I request them.
- Use the minimum testing necessary to establish confidence, then continue; broaden testing only when failures or material risks justify it.
- If a command requires unavailable credentials or external authorization, complete all unaffected work and give me the exact minimal action needed.

## Definition of done

The project is ready for my final review when:

- the approved state-year dataset can be reproduced;
- sources, definitions, transformations, and exclusions are documented;
- data-quality checks pass or exceptions are explicitly documented;
- the selected models use an honest validation design;
- results are compared with a meaningful baseline;
- conclusions do not exceed the evidence;
- report tables and figures are generated from code;
- milestone slides satisfy the professor's constraints;
- all major decisions are recorded;
- I can reproduce the workflow and explain every central methodological choice;
- remaining `[AUTHOR DECISION REQUIRED]` items are clearly identified.

## Start now

Begin with Phase 0. Inspect the current project, establish the baseline, and complete all safe work through the preparation for Decision Gate 1. Do not stop after writing a plan.
