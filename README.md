# PSScriptAnalyzerCustomRules
Some custom PSScriptAnalyzer rules

## Measure-AvoidPositionalCommandParameter

`
   Rule to detect positional parameters inside an CommandParameterAst
    There are three case in which an Argument is considered as Positional
    1. An argument follows direct to the CommandName
    2. An argument follows direct to a SwitchParameter
    3. An argument has no Parameter as direct precursor
    Get-Command is used to get the CmdletInfo Object from the command.
    The Command must also be rocognized by Get-Command
    The CmdletInfo Object is used to Resolve the parameter so we can detect switchparameter
    
    parameters with typos or wrong names, which cannot be resolved
    are treated like an parameter which consumes an argument
    Those parameter should be detecte by other rules! Also wrong typed commands.
    
    an argument which follows direct after an resolved or unresolved parameter is treated as bound to the parameter!
`

