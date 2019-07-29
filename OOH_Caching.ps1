<#

 This function was pulled from https://github.com/msftrncs/PwshReadXmlPList
 Copyright (c) 2019 Carl Morris

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.


.SYNOPSIS
    Convert a XML Plist to a PowerShell object
.DESCRIPTION
    Converts an XML PList (property list) in to a usable object in PowerShell.
    Properties will be converted in to ordered hashtables, the values of each property may be integer, double, date/time, boolean, string, or hashtables, arrays of any these, or arrays of bytes.
.EXAMPLE
    $pList = [xml](get-content 'somefile.plist') | ConvertFrom-Plist
.PARAMETER plist
    The property list as an [XML] document object, to be processed.  This parameter is mandatory and is accepted from the pipeline.
.INPUTS
    system.xml.document
.OUTPUTS
    system.object
.NOTES
    Script / Function / Class assembled by Carl Morris, Morris Softronics, Hooper, NE, USA
    Initial release - Aug 27, 2018
.LINK
    https://github.com/msftrncs/PwshReadXmlPList
.FUNCTIONALITY
    data format conversion
#>
function ConvertFrom-Plist {
    Param(
        # parameter to pass input via pipeline
        [Parameter(Mandatory, Position = 0,
            ValueFromPipeline, ValueFromPipelineByPropertyName,
            HelpMessage = 'XML Plist object.')]
        [ValidateNotNullOrEmpty()]
        [xml]$plist
    )

    # define a class to provide a method for accelerated processing of the XML tree
    class plistreader {
        # define a static method for accelerated processing of the XML tree
        static [object] processTree ($node) {
            return $(
                <#  iterate through the collection of XML nodes provided, recursing through the children nodes to
                extract properties and their values, dictionaries, or arrays of all, but note that property values
                follow their key, not contained within them. #>
                if ($node.HasChildNodes) {
                    switch ($node.Name) {
                        dict {
                            # for dictionary, return the subtree as a ordered hashtable, with possible recursion of additional arrays or dictionaries
                            $collection = [ordered]@{}
                            $currnode = $node.FirstChild # start at the first child node of the dictionary
                            while ($null -ne $currnode) {
                                if ($currnode.Name -eq 'key') {
                                    # a key in a dictionary, add it to a collection
                                    if ($null -ne $currnode.NextSibling) {
                                        # note: keys are forced to [string], insures a $null key is accepted
                                        $collection[[string][plistreader]::processTree($currnode.FirstChild)] = [plistreader]::processTree($currnode.NextSibling)
                                        $currnode = $currnode.NextSibling.NextSibling # skip the next sibling because it was the value of the property
                                    } else {
                                        throw "Dictionary property value missing!"
                                    }
                                } else {
                                    throw "Non 'key' element found in dictionary: <$($currnode.Name)>!"
                                }
                            }
                            # return the collected hash table
                            $collection
                            continue
                        }
                        array {
                            # for arrays, recurse each node in the subtree, returning an array (forced)
                            , @($node.ChildNodes.foreach{ [plistreader]::processTree($_) })
                            continue
                        }
                        string {
                            # for string, return the value, with possible recursion and collection
                            [plistreader]::processTree($node.FirstChild)
                            continue
                        }
                        integer {
                            # must be an integer type value element, return its value
                            [plistreader]::processTree($node.FirstChild).foreach{
                                # try to determine what size of interger to return this value as
                                if ([int]::TryParse($_, [ref]$null)) {
                                    # a 32bit integer seems to work
                                    $_ -as [int]
                                } elseif ([int64]::TryParse($_, [ref]$null)) {
                                    # a 64bit integer seems to be needed
                                    $_ -as [int64]
                                } else {
                                    # try an unsigned 64bit interger, the largest available here.
                                    $_ -as [uint64]
                                }
                            }
                            continue
                        }
                        real {
                            # must be a floating type value element, return its value
                            [plistreader]::processTree($node.FirstChild) -as [double]
                            continue
                        }
                        date {
                            # must be a date-time type value element, return its value
                            [plistreader]::processTree($node.FirstChild) -as [datetime]
                            continue
                        }
                        data {
                            # must be a data block value element, return its value as [byte[]]
                            [convert]::FromBase64String([plistreader]::processTree($node.FirstChild))
                            continue
                        }
                        default {
                            # we didn't recognize the element type!
                            throw "Unhandled PLIST property type <$($node.Name)>!"
                        }
                    }
                } else {
                    # return simple element value (need to check for Boolean datatype, and process value accordingly)
                    switch ($node.Name) {
                        true { $true; continue } # return a Boolean TRUE value
                        false { $false; continue } # return a Boolean FALSE value
                        default { $node.Value } # return the element value
                    }
                }
            )
        }
    }

    # process the 'plist' item of the input XML object
    [plistreader]::processTree($plist.item('plist').FirstChild)
}

#Dry run will just show the links and NOT download anything
$dryrun = $true

[string[]]$models ="iPad7,5","iPad6,11" #add more if required
<#
iPad2,5 : iPad mini
iPad3,4 : 4th Gen iPad
iPad4,1 : iPad Air (WiFi)
iPad4,4 : iPad mini Retina (WiFi)
iPad4,7 : iPad mini 3 (WiFi)
iPad5,1 : iPad mini 4 (WiFi)
iPad5,3 : iPad Air 2 (WiFi)
iPad6,3 : iPad Pro (9.7 inch, WiFi)
iPad6,7 : iPad Pro (12.9 inch, WiFi)
iPad6,11 : iPad (2017)
iPad6,12 : iPad (2017)
iPad7,1 : iPad Pro 2nd Gen (WiFi)
iPad7,3 : iPad Pro 10.5-inch
iPad7,4 : iPad Pro 10.5-inch
iPad7,5 : iPad 6th Gen (WiFi)
iPad8,1 : iPad Pro 3rd Gen (11 inch, WiFi)
iPad8,2 : iPad Pro 3rd Gen (11 inch, 1TB, WiFi)
iPad8,5 : iPad Pro 3rd Gen (12.9 inch, WiFi)
iPad8,6 : iPad Pro 3rd Gen (12.9 inch, 1TB, WiFi)
#>

#change below to the sites caching server's IP address
$CachingIP = "10.3.2.1"
$CachingPort = "12345"
$CachingServer =$Cachingip+":"+$CachingPort

Invoke-RestMethod -Uri http://mesu.apple.com/assets/com_apple_MobileAsset_SoftwareUpdate/com_apple_MobileAsset_SoftwareUpdate.xml -Method Get -OutFile "c:\temp\info.plist"

$pList = [xml](get-content "c:\temp\info.plist") | ConvertFrom-Plist
$ipads= $pList.Assets

Foreach ($model in $models){

    $selectipads = $ipads|Where-Object -property supporteddevices -eq $model |Where-Object -property ReleaseType -ne "Beta"
    Foreach ($selectipad in $selectipads){
    [string]$URL = $selectipad|%{$_.__BaseURL+$_.__RelativePath}
    [string]$OSVer = $selectipad|%{$_.OSversion}
          
    [string]$Build = $selectipad|%{$_.Build}
    [string]$ipsw = "iPad_64bit_"+$OSVer+"_"+$Build+"_Restore.ipsw"
    if ($url -like "http://updates-http.cdn-apple.com*"){
        $url = $url-replace 'updates-http.cdn-apple.com',$CachingServer
        $sourceURL = "?source=updates-http.cdn-apple.com"
    }
    if ($url -like "http://appldnld.apple.com*"){
        $url = $url-replace 'appldnld.apple.com',$CachingServer
        $sourceURL = "?source=appldnld.apple.com"
    }
    
    Write-host "Model: " $model
    write-host "URL for firmware: "$Url$sourceURL
    
    if ($dryrun = $false){
       Invoke-RestMethod -Uri $Url$sourceURL -Method Get -OutFile $StoreDir
    }
    }

}
