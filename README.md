# Pre-course survey: Git for Scientists

The pre-course survey of the "Git for Scientists" workshop, built with [surveydown](https://surveydown.org) (R, Quarto and Shiny) after the surveys of [agentsforsci-dev](https://github.com/agentsforsci-dev/pre-course-survey) and gitklar-dev. Participants join a per-iteration organisation (`gitforsci-<iteration>`); the development material, this survey included, lives in `gitforsci-dev`.

First iteration that uses it: `gitforsci-rdc`, the 120 minute workshop at the Research Data Conference 2026 in Bern, Friday 20 November 2026, 09:30 to 11:30. The survey is step 1 of the pre-course work. Its answers decide which software the hands-on part uses (RStudio with Git, GitHub Desktop or Positron); the setup instructions follow on the workshop website on Monday 16 November 2026.

## What the survey asks

English, 10 to 15 minutes, 22 required questions on six pages and 2 optional ones (`ai_tools`, `teaching_context`). Consent comes first, so a session that is abandoned later stores no email address without it.

| Page | Question id | Question | Source |
|---|---|---|---|
| agreement | `consent` | Consent, one box | agentsforsci and gitklar, adapted |
| about | `email` | Email address, validated | gitklar |
| about | `github_account` | GitHub account yes, no, don't know | gitklar |
| about | `github_username` | Username, only with an account | agentsforsci, gitklar |
| about | `github_username_new` | Username after creating the account during the survey, shown for no and don't know, with the steps | gitklar |
| about | `os`, `os_other` | Operating system of the laptop | agentsforsci, gitklar |
| about | `install_rights` | Can install software themselves | new (managed laptops) |
| about | `role`, `role_other` | Role | new |
| about | `teaches_git` | Teaches Git and GitHub, plans to, no | new (educator audience) |
| rdm | `rdm_level`, `rdm_level_other` | Where the research data work sits (group, department, central, across institutions, informal, own data) | new, 2026-11-10 |
| rdm | `rdm_activities` | Activities in research data work | new, 2026-11-10 |
| tools | `installed` | Software installed on the laptop | new (software decision) |
| tools | `git_today` | How they work with Git today | new (software decision) |
| tools | `preferred_setup` | Preferred setup for the hands-on part | new (software decision) |
| tools | `ai_tools`, `ai_tools_other` (optional) | AI tools used, short list | agentsforsci, shortened |
| experience | `prog` | Programming experience, general, R, Python (matrix) | agentsforsci |
| experience | `cli_usage` | Command line use | agentsforsci and gitklar, reworded |
| experience | `git_experience` | Git experience | gitklar |
| goals | `learning_goals` | What they want to know or do afterwards | agentsforsci, gitklar |
| goals | `teaching_context` (optional) | Their learners and setting | new |

No browser details and no IP addresses are stored (`capture-metadata: false`).

## Decisions taken before the survey went out

Decided on 9 and 10 November 2026:

- **Identifier.** GitHub username and email, both required. The username is needed to invite people to the course organisation; the email carries the setup instructions after the software decision, because the conference organisers hold the registrations.
- **Database.** The agentsforsci Supabase project in Zurich (`eu-central-2`), one new table per iteration, here `gitforsci_rdc_2026_11`.
- **Hosting.** Posit Connect Cloud, account larnsce, slug `gitforsci-rdc-survey`. Contact and consent name the ETH address.
- **Consent first.** The consent box is the first page.
- **Due date.** Friday 13 November 2026. The software decision follows on Monday 16 November from the answers.

## Run the survey locally

Quarto is not on the PATH of this Mac, so point surveydown at the RStudio copy:

```sh
QUARTO_PATH=/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto \
  Rscript -e 'shiny::runApp("app.R", port = 8765, launch.browser = FALSE)'
```

Test answers go to `preview_data.csv`, which is git-ignored. In preview mode `app.R` does not call `sd_db_connect()`, so a local run never touches the database, even when `.env` holds real credentials. surveydown re-renders `survey.qmd` into `_survey/` when the file changed.

After any change to `survey.qmd`, open one throwaway session first. The session that re-parses the file does not restore answers on Previous.

## Test

With the app running, from this folder:

```sh
Rscript tests/clickthrough.R
```

The script uses chromote (headless Chrome) and is tuned to preview mode. It checks that every page loads without duplicate ids, that the follow-up fields appear only for their answers and block Next only while visible, that the consent page blocks without the box, that bad email addresses and usernames are refused, that "none" together with other picks is refused, and that one full test response reaches the end page and lands in `preview_data.csv` without IP address or browser columns.

For database mode, `Rscript tests/smoke_database.R [url] [email]` walks the happy path once with long waits (the first database session is slow while surveydown adds the columns). It is the test response of step 3 below and the live check of step 7.

## Database and deployment: steps for Lars

These steps need Lars's own accounts. Steps 6 and 7 are the procedure for every later change: commit on `dev`, redeploy, check the live page, then open the pull request into `main`.

1. **Connection values.** Copy the `.env` of the agentsforsci survey into this folder (same Supabase project, session pooler host, port **5432**, not the transaction pooler on 6543) and set the table for this iteration:

   ```
   SD_HOST=<session pooler host>
   SD_PORT=5432
   SD_DBNAME=postgres
   SD_USER=<pooler user, postgres.<project ref>>
   SD_PASSWORD=<database password>
   SD_TABLE=gitforsci_rdc_2026_11
   ```

   `.env` is git-ignored and never leaves the machine. `app.R` sets `PGSSLMODE=require` itself, so every connection uses TLS, also on Connect Cloud.
2. **Database mode.** Set `mode: database` in the `survey.qmd` YAML header.
3. **Test response.** Run the app locally once and send one full test response with the address `test@example.org` (`Rscript tests/smoke_database.R`). surveydown creates the table, adds the columns on first use and turns on row level security. The admin scripts drop that address on pull; delete the row in Supabase when the live check is done too.
4. **Read-only role.** In `gitforsci-dev/admin`, run `R/setup_readonly_role.R` with `SURVEY_ENV` pointing at this `.env`, so the admin scripts read the table through a read-only role.
5. **Connect Cloud login.** Once, in your own R console: `rsconnect::connectCloudUser()`.
6. **Deploy.** From a terminal, with Quarto exported:

   ```sh
   export QUARTO_PATH=/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto
   ~/Documents/gitrepos/context-agentsforsci/surveydown-skill/deploy-posit-cloud/deploy.sh \
     --title "Git for Scientists at RDC 2026: pre-course survey" \
     --slug gitforsci-rdc-survey \
     --dir ~/Documents/gitrepos/context-gitforsci/gh-org-gitforsci-dev/pre-course-survey
   ```

   Without `QUARTO_PATH` the script ships no `_survey/` cache and gives no message. The script sends the `SD_*` values as content secrets and sets access to public. The live address is `https://larnsce-gitforsci-rdc-survey.share.connect.posit.cloud/`.
7. **Live check.** Open the live address in a fresh private window, answer once with `test@example.org`, and delete that row in Supabase.

## Next iteration

Edit the cohort values in the first chunk of `survey.qmd` (dates, website, contact), set a new `SD_TABLE` in `.env`, add the table to the read-only role's policy with `setup_readonly_role.R`, and redeploy under a new slug.

## Responses never enter git

Responses are personal data. `.env`, `preview_data.csv` and `local_data.csv` are git-ignored. Exports belong in a folder outside any repository.

## License

CC-BY-4.0. Adapted from the agentsforsci and gitklar pre-course surveys.
