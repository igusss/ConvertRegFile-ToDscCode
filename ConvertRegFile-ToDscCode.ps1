<#
.SYNOPSIS   
Convert RegFiles to DSC Registry Resources
    
.DESCRIPTION 
The script accept a path and will run recursively on the folders over all the .REG files. It will return the DSC Registry Resources

.PARAMETER 
This accept the parameter Path (and the switch Recurse)
	
.NOTES   
Name: ConvertRegFile-ToDscCode.ps1
Author: Alejandro Loiacono
Version: 1.0
DateCreated: 2017-08-15

.EXAMPLE   
.\ConvertRegFile-ToDscCode.ps1 -Path C:\Temp\1TypeofeachEntry.reg

Description:
$valueData ='12345678901234567890abcdef' #ValueData for HKEY_CURRENT_USER_Ale_Binary
Registry HKEY_CURRENT_USER_Ale_Binary
{
    Key = 'HKEY_CURRENT_USER\Ale'
    ValueName = 'Binary'
    Ensure = 'Present'
    Force = $true
    Hex = $true
    ValueData = $valueData 
    ValueType = 'Binary'
}

$valueData ='ffffffff' #ValueData for HKEY_CURRENT_USER_Ale_Dword
Registry HKEY_CURRENT_USER_Ale_Dword
{
    Key = 'HKEY_CURRENT_USER\Ale'
    ValueName = 'Dword'
    Ensure = 'Present'
    Force = $true
    Hex = $true
    ValueData = $valueData 
    ValueType = 'Dword'
}

$valueData ='ffffffffffffffff' #ValueData for HKEY_CURRENT_USER_Ale_Qword
Registry HKEY_CURRENT_USER_Ale_Qword
{
    Key = 'HKEY_CURRENT_USER\Ale'
    ValueName = 'Qword'
    Ensure = 'Present'
    Force = $true
    Hex = $true
    ValueData = $valueData 
    ValueType = 'Qword'
}

$valueData = [System.Management.Automation.PSSerializer]::Deserialize('<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04">
  <Obj RefId="0">
    <TN RefId="0">
      <T>System.Object[]</T>
      <T>System.Array</T>
      <T>System.Object</T>
    </TN>
    <LST>
      <S>This</S>
      <S>is</S>
      <S>a</S>
      <S>multi</S>
      <S>string</S>
      <S></S>
    </LST>
  </Obj>
</Objs>')
Registry HKEY_CURRENT_USER_Ale_Multistring
{
    Key = 'HKEY_CURRENT_USER\Ale'
    ValueName = 'Multistring'
    Ensure = 'Present'
    Force = $true
    Hex = $false
    ValueData = $valueData 
    ValueType = 'Multistring'
}

$valueData ='This is a expandable string' #ValueData for HKEY_CURRENT_USER_Ale_Expandable
Registry HKEY_CURRENT_USER_Ale_Expandable
{
    Key = 'HKEY_CURRENT_USER\Ale'
    ValueName = 'Expandable'
    Ensure = 'Present'
    Force = $true
    Hex = $false
    ValueData = $valueData 
    ValueType = 'ExpandString'
}

# This is a comment
$valueData ='This is the default value' #ValueData for HKEY_CURRENT_USER_Ale_
Registry HKEY_CURRENT_USER_Ale_
{
    Key = 'HKEY_CURRENT_USER\Ale'
    ValueName = ''
    Ensure = 'Present'
    Force = $true
    Hex = $false
    ValueData = $valueData 
    ValueType = 'String'
}

$valueData ='ffffffff' #ValueData for HKEY_CURRENT_USER_Ale_Remove
Registry HKEY_CURRENT_USER_Ale_Remove
{
    Key = 'HKEY_CURRENT_USER\Ale'
    ValueName = 'Remove'
    Ensure = 'Absent'
    Force = $true
    Hex = $true
    ValueData = $valueData 
    ValueType = 'Dword'
}

# and another
# this is another comment
$valueData ='This is a string' #ValueData for HKEY_CURRENT_USER_Software_Lele_String
Registry HKEY_CURRENT_USER_Software_Lele_String
{
    Key = 'HKEY_CURRENT_USER\Software\Lele'
    ValueName = 'String'
    Ensure = 'Absent'
    Force = $true
    Hex = $false
    ValueData = $valueData 
    ValueType = 'String'
}

.SOURCES
  https://msdn.microsoft.com/en-us/powershell/dsc/registryresource
  https://github.com/PowerShell/xPSDesiredStateConfiguration
  https://support.microsoft.com/en-us/help/310516/how-to-add--modify--or-delete-registry-subkeys-and-values-by-using-a
  https://blogs.technet.microsoft.com/heyscriptingguy/2011/09/09/convert-hexadecimal-to-ascii-using-powershell/
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Path,
    [switch]$Recurse
)

begin{
    If(!(Test-Path $Path)){
        Throw "Directory does not Exist"
    }    
    #######FUNCTIONS########
    function Convert-RegToObj($Path){
    $trueString = '$true'
    $falseString = '$false'        
    Function RemoveMultiLines($file){
        $content = Get-Content $file.FullName
        foreach($line in $content){
            if ($line -ne "" -and  $line -inotlike "Windows Registry Editor Version*"){ 
                If ($line -like "*\"){
                    $partialLine += $line
                }else{
                    $completeLine = ($partialLine+$line).replace("\  ","")
                    $partialLine=""
                    $completeLine
                }
            }
        }
    }

    If ($Recurse){
        $regFiles = Get-ChildItem $path -Recurse -Filter *.reg
    }else{
        $regFiles = Get-ChildItem $path -Filter *.reg
    }

    if ( $regFiles.count -eq 0) {
        Throw "No Reg Files Found"
    }

    $cleanContentofFiles+= foreach ($file in $regFiles){
        RemoveMultiLines -file $file
    }
    #$output

    $i=0  #Track line number to reorder comments after  Sort Unique
    $result+=foreach ($line in $cleanContentofFiles){
        $i++
        If($line.Contains("[") -and $line.Contains("]") ){
            If ($line.Contains("[-")){
                $keyEnsure = "Absent"
                $key= "[$($line.split('-')[1])"
            }else{
                $key= $line
                $keyEnsure = "Present"
            }
        }else{
            $keyline = $key 
            $lineEnsure = $keyEnsure #This is needed as a line coudl be marked as Absent "-"  or the whole key could be marked as Absent
     
            if($line -like '@*'){ #It is the Default Value
                    $type = "String"
                    $Value= ""
                    $data = $line.split("=")[1].Trim('"')
             }elseif($line -like ';*'){ #It is a Comment
                $type = "Comment"
                $Value= $line.split(";")[1]
                $keyline= ""
                $lineEnsure=""
                $data = $line.split(";")[1]
            }elseif($line -like '"*'){ #It is a Property
                $typeRaw = $line.split("=")[1].split(":")[0]
                $dataRaw = $line.split("=")[1].split(":")[1]
                $value= $line.split("=")[0].trim('"')
                if($typeRaw.StartsWith("-") ){
                    $lineEnsure = "Absent"
                    $typeRaw = $typeRaw.split("-")[1]
                }
                Switch($typeRaw){
                    'dword' {
                        $type="Dword"
                        $data=$dataRaw
                        If ($data -eq "00000000"){  # If not set to 00000000, we are gettting error that value cannot be 0
                           $hex = $falseString
                        }else{
                            $hex = $trueString
                        }
                    }
                    'hex(b)' {
                        $type="Qword"
                        $data=$dataRaw.replace(",","")
                        $hex = $trueString
                    }
                    'hex(7)' {
                        $type="Multistring"
                        $hex = $falseString
                        $multi = $dataRaw  -split ",00,00,"  ##00 Is the new line
                        $dataRaw =@()
                        $dataRaw +=Foreach ($line in $Multi){
                            $CompLine= ""
                            $line -split "," | ?{$_ -ne "00"}  | %{$compline+=[char]([convert]::toint16($_,16))}
                            $CompLine
                        }
                        $data = [System.Management.Automation.PSSerializer]::Serialize($Dataraw)  # We Serialize to after Convert it back to the object on the DSC Resource
                    }
                    'hex(2)' {
                        $hex = $falseString
                        $type="ExpandString"
                        $data = ""
                        $dataRaw -split "," | ?{$_ -ne "00"} | %{$data +=[char]([convert]::toint16($_,16))}
                    }
                    'hex' {
                        $type="Binary"
                        $data = ($line.split("=")[1].split(":")[1]).replace(",","")
                        $hex = $trueString
                    }
                    default {
                        $type="String"
                        $data = $line.split("=")[1].trim('-').trim('"')
                        $hex = $falseString
                    }
                }
            }

            $output = "" | Select-Object Key,Type,Value,Data,Ensure,Hex,Line
            $output.key = $keyline
            $output.value = $value
            $output.type = $type
            $output.data = $data
            $output.ensure = $lineEnsure
            $output.hex = $hex
            $output.line = $i
            $output
        }
    }
    $result | Sort-Object key,value -Unique |Sort-Object line 
}
    function Convertto-DSC($RegObject){

    $trueString = '$true'
    $valueDataString = '$valueData'

    foreach ($line in $RegObject){
        if ($line.type -eq  "Comment"){
            "# $($line.data)"
        }else{
            $DSCname = "$($line.key.trim('[').trim(']'))_$($line.Value)"
            $DSCname = $DSCname.replace("\","_").replace(" ","_").replace("(","_").replace(")","_").replace(".","_")
            $key = ($line.KEY).trim("[").trim("]")
            if ($line.type -eq  "Multistring"){
                "$valueDataString = [System.Management.Automation.PSSerializer]::Deserialize('$($line.data)')" 
            }else{
                "$valueDataString ='$($line.data)' #ValueData for $DSCname"
            }

            @"
Registry $DSCname
{
    Key = '$key'
    ValueName = '$($line.Value)'
    Ensure = '$($line.ensure)'
    Force = $trueString
    Hex = $($line.hex)
    ValueData = $valueDataString 
    ValueType = '$($line.type)'
}

"@ 
        }
    }
}
    ######END FUNCTIONS#####
}process{
    $RegObject =Convert-RegToObj -Path $path
    Convertto-DSC -RegObject $RegObject
}
   