#Requires -Version 3.0

# Import Localized Data
Import-LocalizedData -BindingVariable Messages

Function New-PsScriptAnalyzerCorrectionExtent {
    <#
.SYNOPSIS
    Function to Create a new CorrectionExtent Object for the PSScriptAnalyser result
#>

    [CmdletBinding()]
    param(

        [Parameter(Mandatory = $True)]
        [Int]
        $StartLineNumber,

        [Parameter(Mandatory = $True)]
        [Int]
        $EndLineNumber,

        [Parameter(Mandatory = $True)]
        [Int]
        $StartColumnNumber,

        [Parameter(Mandatory = $True)]
        [Int]
        $EndColumnNumber,

        [Parameter(Mandatory = $True)]
        [String]
        $ReplacementText,

        [String]
        $Path,

        [String]
        $Description
    )

    New-Object `
        -TypeName 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent' `
        -ArgumentList $startLineNumber, $endLineNumber, $startColumnNumber, $endColumnNumber, $replacementText, $path, $description
}

Function New-PsScriptAnalyzerDiagnosticRecord {
    <#
.SYNOPSIS
    Function to Create a new DiagnosticRecord Object for the PSScriptAnalyser result
.PARAMETER message
    A string about why this diagnostic was created
.PARAMETER extent
    The place in the script this diagnostic refers to
.PARAMETER ruleName
    The name of the rule that created this diagnostic
.PARAMETER severity
    The severity of this diagnostic
.PARAMETER scriptPath
    The full path of the script file being analyzed
.PARAMETER suggestedCorrections
    The correction suggested by the rule to replace the extent text
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]
        $Message,

        [Parameter(Mandatory = $True)]
        [System.Management.Automation.Language.IScriptExtent]
        $Extent,

        [Parameter(Mandatory = $True)]
        [String]
        $RuleName,

        [Parameter(Mandatory = $True)]
        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticSeverity]
        $Severity,

        [String]
        $ScriptPath = '',


        [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]
        $SuggestedCorrections = $Null

    )

    New-Object `
        -TypeName 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord' `
        -ArgumentList $Message, $Extent, $RuleName, $Severity, $ScriptPath, $null, $SuggestedCorrections

}

<#
.SYNOPSIS
    Rule to detect positional parameters inside an CommandParameterAst
.DESCRIPTION
    Rule to detect positional parameters inside an CommandParameterAst
.EXAMPLE
    TODO: Measure-PositionalCommandParameter -ScriptBlockAst $ScriptBlockAst
.INPUTS
    [System.Management.Automation.Language.ScriptBlockAst]
.OUTPUTS
    [Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]]
.NOTES
    Author: Peter Kriegel
    Version: 0.0.1
    Date: 20.February.2018
    History of changes:
        V.0.0.1 Initial release
        Added:
        Removed:
        Changed:
#>
function Measure-PositionalCommandParameter {

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )


    begin {

        $InvocationName = $PSCmdlet.MyInvocation.InvocationName

        Function New-DiagnosticRecordInternal {

            param(
                $Extent
            )

            New-PsScriptAnalyzerDiagnosticRecord `
                -Message $Messages.MeasurePositionalCommandParameter -Extent $Extent -RuleName $InvocationName -Severity 'Warning'
        }
    }

    Process {
        $results = [System.Collections.ArrayList]@()

        try {
            #region Finds ASTs that match the predicates.
            $ScriptBlockAst.FindAll( {$args[0] -is [System.Management.Automation.Language.CommandAst]}, $true) | ForEach-Object {

                Write-Debug '--- Beginn to process a CommandAst ---'

                # getting rich informations about the command with Get-Command
                $CmdletInfo = Get-Command -Name ($_.GetCommandName()) -ErrorAction Stop

                # process each element in CommandElements skipping element 0 which is the command himself
                for ($i = 1; $i -lt $_.CommandElements.count; $i++) {

                    If ($_.CommandElements[$i] -isnot [System.Management.Automation.Language.CommandParameterAst]) {

                        If ($i -gt 1 ) {

                            # test if the precursor element is an parameter and is NOT a switch parameter
                            If ($_.CommandElements[$i - 1] -is [System.Management.Automation.Language.CommandParameterAst]) {

                                Try {
                                    $ParameterMetadata = $CmdletInfo.ResolveParameter($_.CommandElements[$i - 1].Extent.Text)
                                }
                                Catch {
                                    $ParameterMetadata = $Null
                                }

                                If ($ParameterMetadata) {

                                    If ($ParameterMetadata.ParameterType.Tostring() -eq 'System.Management.Automation.SwitchParameter') {

                                        # Positional Argument after switch parameter found
                                        Write-Debug "Argument $($_.CommandElements[$i].Extent.Text) is Positional"

                                        $result = New-DiagnosticRecordInternal -Extent $_.CommandElements[$i].Extent
                                        $Null = $results.add($result)

                                    }

                                }

                            }
                            Else {

                                # Positional Argument without leading Parameter Found
                                Write-Debug "Argument $($_.CommandElements[$i].Extent.Text) is Positional"
                                $result = New-DiagnosticRecordInternal -Extent $_.CommandElements[$i].Extent
                                $Null = $results.add($result)
                            }

                        }
                        Else {

                            # Positional Argument direct after command on Position 0 Found
                            Write-Debug "Argument $($_.CommandElements[$i].Extent.Text) is Positional"
                            $result = New-DiagnosticRecordInternal -Extent $_.CommandElements[$i].Extent
                            $Null = $results.add($result)

                        }
                    }
                }
                Write-Debug '--- End to process a CommandAst ---'
            }

            return $results.ToArray()

            #endregion
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}