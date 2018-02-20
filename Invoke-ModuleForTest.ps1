# Create Proxy for Write Debug
# to get Messages without entering the Debugger
Function Write-Debug {
    param (
        [String]
        $Message = ''
    )

    Write-Host -Object $Message -ForegroundColor Magenta

}

# Create Code to Parse
New-Alias -Name WrtH -Value write-host -Force
$code = "WrtH (Get-Content 'C:\temp\message.txt') -nonew -fore 'yellow' 123 -ea Continue 'wer','was','wann' -notExist 'foo'"

# create AST from code
$ScriptBlockAst = [System.Management.Automation.Language.Parser]::ParseInput($Code,[ref]$null,[ref]$Null)

# import the Moduel with the rules to test
Import-Module "$PSScriptRoot\CommunityAnalyzerRules" -Force

##################################################################
# Now Test the Rule !!
Measure-PositionalCommandParameter -ScriptBlockAst $ScriptBlockAst
##################################################################

Remove-Module CommunityAnalyzerRules -Force