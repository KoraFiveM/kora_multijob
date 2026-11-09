# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_multijob — Jobs

  @kora_multijob @checklist @checklist:kora_multijob:open-roster @cat:jobs
  Scenario: Open job roster with /multijob or J
    """
    Checklist test: Run /multijob or press J; 'Employment' panel opens showing Current job and Saved jobs with 'N of 5 jobs saved'.
    """
    When I run the command "/multijob"
    Then the "qbmultijob:roster" app opens
    And I confirm: the 'Employment' panel shows Current job and Saved jobs
    And I confirm: the Saved jobs section shows a count like 'N of 5 jobs saved' (config default maxJobs is 4; accept the actual configured limit)
    When I manually: close the panel
    And I press the "J" key
    Then the "qbmultijob:roster" app opens

  @kora_multijob @checklist @checklist:kora_multijob:current-job-card @cat:jobs
  Scenario: Current job card details
    """
    Checklist test: Check current job card: job label, grade label, Grade and Pay metadata, badge On duty/Off duty.
    """
    When I press the "J" key
    Then the "qbmultijob:roster" app opens
    And I confirm: the current job card shows the job label and the grade label
    And I confirm: the current job card shows Grade and Pay metadata
    And I confirm: the current job card shows an On duty or Off duty badge

  @kora_multijob @checklist @checklist:kora_multijob:switch-active-job @cat:jobs
  Scenario: Make a saved job active
    """
    Checklist test: With 2+ saved jobs click 'Make active' on one; it becomes Current job and the kora_core job changes.
    """
    When I manually: ask a Mod to add a second saved job to my roster if I have fewer than 2
    And I press the "J" key
    Then the "qbmultijob:roster" app opens
    When I manually: click 'Make active' on a saved job that is not the current job
    Then I confirm: that job now appears as Current job in the roster
    And I confirm: my active job changed to that job (check with /playerData or the HUD)

  @kora_multijob @checklist @checklist:kora_multijob:toggle-duty @cat:jobs
  Scenario: Go on/off duty from roster
    """
    Checklist test: On the active job click 'Go off duty' / 'Go on duty'; badge and kora_core duty state update.
    """
    Given my job is "mechanic"
    And I am on duty
    When I press the "J" key
    Then the "qbmultijob:roster" app opens
    When I manually: click 'Go off duty' on the active job
    Then I should be off duty
    And I confirm: the badge shows Off duty
    When I manually: click 'Go on duty' on the active job
    Then I should be on duty
    And I confirm: the badge shows On duty

  @kora_multijob @checklist @checklist:kora_multijob:police-duty-locked @cat:jobs
  Scenario: Police duty locked
    """
    Checklist test: With police active the duty button is absent and shows 'Duty: Managed by job' (disabledDuty.police).
    """
    Given my job is "police"
    When I press the "J" key
    Then the "qbmultijob:roster" app opens
    And I confirm: the duty button is absent and 'Duty: Managed by job' is shown (only applies when disabledDuty.police is enabled; otherwise mark Pass if a normal duty button shows)

  @kora_multijob @checklist @checklist:kora_multijob:leave-job @cat:jobs
  Scenario: Leave a saved job
    """
    Checklist test: Click 'Leave job' on a non-active job and confirm; job removed from roster. Unemployed cannot be left, active job has no leave.
    """
    Given my job is "mechanic"
    When I manually: ask a Mod to add a second saved job to my roster if I have only one
    And I press the "J" key
    Then the "qbmultijob:roster" app opens
    When I manually: click 'Leave job' on a non-active saved job and confirm
    Then I should see a notification containing "Job removed from your roster."
    And I confirm: the job is removed from the roster
    And I confirm: Unemployed has no leave option and the active job has no 'Leave job' button

  @kora_multijob @checklist @checklist:kora_multijob:saved-jobs-search @cat:jobs
  Scenario: Search saved jobs
    """
    Checklist test: With 4+ saved jobs the Saved jobs list shows a search box; filter by job or rank.
    """
    When I manually: ask a Mod to give me jobs until I have 4 or more saved jobs
    And I press the "J" key
    Then the "qbmultijob:roster" app opens
    And I confirm: the Saved jobs list shows a search box
    When I manually: type a job name in the search box
    Then I confirm: the list is filtered by job
    When I manually: clear the search and type a rank name
    Then I confirm: the list is filtered by rank

  @kora_multijob @checklist @checklist:kora_multijob:max-jobs-limit @cat:jobs @manual
  Scenario: Roster limit of 4 jobs
    """
    Checklist test: Add jobs until 4 saved (plus unemployed); adding a further job is rejected.
    """
    When I manually: ask a Mod to run /givejob for me until I have 4 saved jobs plus unemployed
    And I manually: ask the Mod to run /givejob for a further job
    Then I confirm: the further job is rejected and not added to my roster

  @kora_multijob @checklist @checklist:kora_multijob:admin-givejob @cat:jobs @needs:admin
  Scenario: Admin /givejob
    """
    Checklist test: As admin run /givejob [id] [job] [grade]; target gets the job saved in roster and can see it in /multijob.
    """
    When I manually: ask a second player for their id
    And I manually: run /givejob [id] [job] [grade] with the second player's id, a job and a grade
    Then I should see a notification containing "Job saved."
    And I confirm: the other player sees the notification "A job was added to your roster."
    When I manually: ask the second player to run /multijob
    Then I confirm: the other player sees the job saved in their roster

  @kora_multijob @checklist @checklist:kora_multijob:admin-removejob @cat:jobs @needs:admin
  Scenario: Admin /removejob
    """
    Checklist test: As admin run /removejob [id] [job]; job removed from target's roster; non-admin is denied.
    """
    When I manually: run /removejob [id] [job] for a second player who has that job
    Then I should see a notification containing "Job removed."
    And I confirm: the other player no longer has that job in their roster
    When I manually: ask a non-admin player to run /removejob
    Then I confirm: the other player sees 'You do not have permission for this command.'

  @kora_multijob @checklist @checklist:kora_multijob:roster-persists @cat:jobs
  Scenario: Roster persists across relog
    """
    Checklist test: Relog the character; saved jobs and active job are the same as before.
    """
    When I press the "J" key
    Then the "qbmultijob:roster" app opens
    When I manually: note my saved jobs and active job
    And I manually: relog the character
    And I press the "J" key
    Then the "qbmultijob:roster" app opens
    And I confirm: my saved jobs and active job are the same as before

  @kora_multijob @checklist @checklist:kora_multijob:job-icons @cat:jobs
  Scenario: Job icons in roster
    """
    Checklist test: Roster shows distinct icons for police, ambulance, mechanic, taxi, lawyer, news, etc.
    """
    When I manually: ask a Mod to add police, ambulance, mechanic, taxi, lawyer and news jobs to my roster
    And I press the "J" key
    Then the "qbmultijob:roster" app opens
    And I confirm: the roster shows a distinct icon for each of those jobs
