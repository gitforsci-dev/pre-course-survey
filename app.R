# Pre-course survey of Git for Scientists, iteration gitforsci-rdc (RDC 2026).
# Built after gitklar-dev/pre-course-survey and agentsforsci-dev/pre-course-survey.

library(surveydown)

# Database setup --------------------------------------------------------------
#
# The survey runs in preview mode (survey.qmd YAML, `mode: preview`) until the
# Supabase table exists, so answers go to preview_data.csv and no database is
# used. For real answers: copy the .env of the agentsforsci survey, set
# SD_TABLE to gitforsci_rdc_2026_11, and set `mode: database`. Use the SESSION
# pooler (port 5432), not the transaction pooler (6543), see the README.

Sys.setenv(PGSSLMODE = "require")

# sd_db_connect() reads .env and connects whatever the mode is. In preview
# mode, skip the connection, so local test runs never touch the database.
survey_yaml <- local({
  lines <- readLines("survey.qmd", warn = FALSE)
  ends  <- which(lines == "---")
  yaml::yaml.load(paste(lines[(ends[1] + 1):(ends[2] - 1)], collapse = "\n"))
})
survey_mode <- survey_yaml$`survey-settings`$mode

db <- if (identical(survey_mode, "preview")) {
  NULL
} else {
  sd_db_connect(gssencmode = "disable")
}

ui <- sd_ui()

server <- function(input, output, session) {
  # Text fields shown only for the answers they belong to
  sd_show_if(
    sd_value("github_account") == "yes" ~ "github_username",
    sd_value("github_account") %in% c("no", "dont_know") ~ "github_username_new",
    sd_value("os") == "other" ~ "os_other",
    sd_value("role") == "other" ~ "role_other",
    sd_value("rdm_level") == "other" ~ "rdm_level_other",
    "other" %in% sd_value("ai_tools") ~ "ai_tools_other"
  )

  # Checks when the participant clicks Next
  sd_stop_if(
    !grepl(
      "^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$",
      trimws(sd_value("email", as_numeric = FALSE))
    ) ~
      "Please enter a valid email address.",

    isTRUE(sd_value("github_account") == "yes") &
      !grepl(
        "^[A-Za-z0-9-]{1,39}$",
        trimws(sd_value("github_username", as_numeric = FALSE))
      ) ~
      "Please enter your GitHub username without the @. It consists of letters, digits and hyphens.",

    # Same check for the username of an account created during the survey
    isTRUE(sd_value("github_account") %in% c("no", "dont_know")) &
      !grepl(
        "^[A-Za-z0-9-]{1,39}$",
        trimws(sd_value("github_username_new", as_numeric = FALSE))
      ) ~
      "Please enter the username of your new GitHub account, without the @. It consists of letters, digits and hyphens.",

    "none" %in% sd_value("rdm_activities") & length(sd_value("rdm_activities")) > 1 ~
      "Research data work: please choose either \"None of these\" or the activities that are part of your work.",
    any(c("none", "dont_know") %in% sd_value("installed")) & length(sd_value("installed")) > 1 ~
      "Installed software: please choose either \"None of these\", \"I don't know\", or the software that is installed.",
    "not_at_all" %in% sd_value("git_today") & length(sd_value("git_today")) > 1 ~
      "Git today: please choose either \"Not at all\" or the ways you work with Git.",
    "none" %in% sd_value("ai_tools") & length(sd_value("ai_tools")) > 1 ~
      "AI tools: please choose either \"None of the above\" or the tools you have used."
  )

  sd_server(db = db)
}

shiny::shinyApp(ui = ui, server = server)
