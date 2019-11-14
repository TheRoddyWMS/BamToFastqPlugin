# Change Logs

* 1.1.1
  * Bugfix with wrong order and directory usage and creation
  * Versioned conda environment name
  * Conda environment update related to infrastructure software (Python, etc.) in order to have Bash 4.4.18 in the Conda environment (to avoid problems with 4.2 bug and empty arrays)
  * Bugfix: Wrong cvalue type

* 1.1.0
  * Handle unmatched paired-end reads and singletons, incl. sorting
  * Safety waiting time to reduce the chance of missing file
  * Add tests

* 1.0.2
  * Bugfix: Forced deletion of tempfiles
  * Increased default memory limits
  * Better error messages
  
* 1.0.1
  * Bugfix: Filename pattern
  * Bugfix: in yet dysfunctional single-end branch

* 1.0.0
  * first running version
