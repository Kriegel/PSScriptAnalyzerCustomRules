#Requires -Version 3.0

# Import Localized Data
Import-LocalizedData -BindingVariable Messages

Function New-PsScriptAnalyzerCorrectionExtent 
{
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
        $Path = $Null,

        [String]
        $Description = $Null
    )

    New-Object `
    -TypeName 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent' `
    -ArgumentList $StartLineNumber, $EndLineNumber, $StartColumnNumber, $EndColumnNumber, $ReplacementText, $Path, $Description
}

Function New-PsScriptAnalyzerDiagnosticRecord 
{
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
    -ArgumentList $Message, $Extent, $RuleName, $Severity, $ScriptPath, $Null, $SuggestedCorrections
}

<#
        .SYNOPSIS
        Rule to detect positional parameters inside an CommandParameterAst
        .DESCRIPTION
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

        .EXAMPLE
        Measure-AvoidPositionalCommandParameter -ScriptBlockAst $ScriptBlockAst
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

        TODO:
        Add exceptional rule for Select-Object, Where-Object and ForEach-Object !?
        Select-Object can have calculatet Properties in a Hashtable
        Where-Object has the new simple syntax.
        ForEach-Object schould have a simple use wit curly brackets


#>
Function Measure-AvoidPositionalCommandParameter 
{
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.Powershell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    Param
    (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.ScriptBlockAst]
        $ScriptBlockAst
    )


    begin {

        $InvocationName = $PSCmdlet.MyInvocation.InvocationName

        Function New-DiagnosticRecordInternal 
        {
            [CmdletBinding()]
            param(
                $Extent
            )

            New-PsScriptAnalyzerDiagnosticRecord `
            -Message "$($Messages.MeasurePositionalCommandParameter): $($Extent.Text)" -Extent $Extent -RuleName $InvocationName -Severity 'Warning'
        }
    }

    Process {
        $results = [System.Collections.ArrayList]@()

        try 
        {
            $CommandAsts = $ScriptBlockAst.FindAll( {$args[0] -is [System.Management.Automation.Language.CommandAst]}, $True)
           
            Write-Debug -Message "--- CommandAst count $([Array]$CommandAsts.count) ---"

            ForEach($CurrendCmdAst in ([Array]$CommandAsts)) 
            {
                Write-Debug -Message "--- Beginn to process a CommandAst $($CurrendCmdAst.GetCommandName()) ---"

                # getting rich informations about the command with Get-Command
                $CmdletInfo = Get-Command -Name ($CurrendCmdAst.GetCommandName()) -ErrorAction SilentlyContinue

                # execute only if we have an CmdletInfo Object
                If($Null -ne $CmdletInfo) 
                {
                    Write-Debug -Message '--- we have an CmdletInfo ---'

                    # process each element in CommandElements skipping element 0 which is the command himself
                    for ($i = 1; $i -lt $CurrendCmdAst.CommandElements.count; $i++) 
                    {
                        If ($CurrendCmdAst.CommandElements[$i] -isnot [System.Management.Automation.Language.CommandParameterAst]) 
                        {
                            If ($i -gt 1 ) 
                            {
                                # test if the precursor element is an parameter and is NOT a switch parameter
                                If ($CurrendCmdAst.CommandElements[$i - 1] -is [System.Management.Automation.Language.CommandParameterAst]) 
                                {
                                    Try 
                                    {
                                        $ParameterMetadata = $CmdletInfo.ResolveParameter($CurrendCmdAst.CommandElements[$i - 1].Extent.Text)
                                    }
                                    Catch 
                                    {
                                        $ParameterMetadata = $Null
                                    }

                                    If ($ParameterMetadata) 
                                    {
                                        If ($ParameterMetadata.ParameterType.Tostring() -eq 'System.Management.Automation.SwitchParameter') 
                                        {
                                            # Positional Argument after switch parameter found
                                            Write-Debug -Message "Argument $($CurrendCmdAst.CommandElements[$i].Extent.Text) is Positional"

                                            $result = New-DiagnosticRecordInternal -Extent $CurrendCmdAst.CommandElements[$i].Extent
                                            $Null = $results.add($result)
                                        }
                                    }
                                }
                                Else 
                                {
                                    # Positional Argument without leading Parameter Found
                                    Write-Debug -Message "Argument $($CurrendCmdAst.CommandElements[$i].Extent.Text) is Positional"
                                    $result = New-DiagnosticRecordInternal -Extent $CurrendCmdAst.CommandElements[$i].Extent
                                    $Null = $results.add($result)
                                }
                            }
                            Else 
                            {
                                # Positional Argument direct after command on Position 0 Found
                                Write-Debug -Message "Argument $($CurrendCmdAst.CommandElements[$i].Extent.Text) is Positional"
                                $result = New-DiagnosticRecordInternal -Extent $CurrendCmdAst.CommandElements[$i].Extent
                                $Null = $results.add($result)
                            }
                        }
                    }
                    Write-Debug -Message "--- End to process a CommandAst $($CurrendCmdAst.GetCommandName()) ---"
                }
            }

            return $results.ToArray()
        }
        catch 
        {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
}
