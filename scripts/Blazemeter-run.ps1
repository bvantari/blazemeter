
 param (
    [string]$apikey,
    [string]$apisecret,	
    [string]$testidinput="",
	[string]$showtaillog ='true',
	[string]$createtest ='false',
	[string]$testname='',
	[string]$projectid='',
    [string]$inputallfiles="null",
	[string]$inputstartfile="null",
	[string]$totalusers=20,
	[string]$duration=20,
	[string]$rampup=1,
	[string]$Uploadfilechk='false',
	[string]$ContinuePipeline='true',
	[string]$multitests='false',
	[string]$functionaltest='false',
	# [string]$workspaceid='',
    # [string]$datamodelid='',
    [psobject]$modeldata="{}",
    [string]$env_variable="{}",
    [string]$jmeterproperties="null",
    [string]$reportname="null",
    [string]$note ="null",
    [string]$iterations_config = 'false',
    [string]$iterations=1,
    [string]$testRunByTestName = 'false',
    [string]$ignoreSLA = 'false'
    )


Function getStatus ([string]$masterId) {
	$TestStatusUrl = "https://a.blazemeter.com/api/v4/masters/"+$masterId+"/status?events=false"
	$TestStatusResponse = Invoke-RestMethod $TestStatusUrl -Method Get -Headers $hdrs 
	$progress = $TestStatusResponse.result.progress
	return $progress        
}


Function waitForFinish ([string]$masterId) {
	$currMinute = 0
	$minutesPassed = 0
	$timer = [Diagnostics.Stopwatch]::StartNew()
	while ($true) {
		$status = getStatus($masterId)
		if ($status -eq 140) {
			$timer.Stop();
			return;
		}
		Start-Sleep -Seconds 10
		$minutesPassed = [math]::Floor($timer.Elapsed.TotalMinutes)
		if ($minutesPassed -ne $currMinute) {
			$currMinute = $minutesPassed
			Write-Host "Check if test is still running... Time passed since start: "$minutesPassed" minutes."
		}
	}
}

Function UpdateTestDetails () {
	# Authorization generation
	$BasicAuthKey  =  $apikey  +":" +$apisecret;
	$BasicAuth = [System.Text.Encoding]::UTF8.GetBytes($BasicAuthKey);
	$AuthorizationKey = "Basic "+ [System.Convert]::ToBase64String($BasicAuth) ;
	$hdrs = @{};
	$hdrs.Add("Authorization",$AuthorizationKey);

	$TestDetailsUrl = "https://a.blazemeter.com/api/v4/tests/"+$testidinput

	$ModelResponse = Invoke-RestMethod $TestDetailsUrl -Method GET -Headers $hdrs;

	try{
        Write-Host "New v1.4.2 ."
        Write-Host "Before "$modeldata
        $modeldata = $modeldata | ConvertFrom-Json
        $modelProperties = $modeldata.psobject.properties
        foreach($props in $modelProperties) {
            if (-not $modelProperties[$props.Name].Value.Contains('"')) {
                $modelProperties[$props.Name].Value = '"'+$props.Value+'"'
            }
        }
        Write-Host "After "$modeldata
	} catch {
		Write-Error $_.Exception.Message;
		exit 1;
	}



    if ($null -eq $ModelResponse.result.dependencies.data.entities.default) {
        $ModelResponse.result.dependencies.data.entities.datamodel.requirements = $modeldata
	} else {
	    $ModelResponse.result.dependencies.data.entities.default.requirements = $modeldata
    }

    if ($null -ne $ModelResponse.result.configuration.enableTestData) {
        $ModelResponse.result.configuration.enableTestData = $true
    }
	$json = $ModelResponse.result | ConvertTo-Json -Depth 9


	Write-Host "Updating test data"
	$ModelResponse = Invoke-RestMethod $TestDetailsUrl -Method Put -Headers $hdrs -Body $json;

	# ./Blazemeter-run.ps1 -apikey "38e53fd821771b102b5bfddc" -apisecret "c9fb4b4be583657d952d3d25103b28590811e7b0f43bf8d7d9107b6345ae752f15a21d50" testidinput "9998412" -workspaceid "838258" -datamodelid "8df6aaaf-d1ac-56a1-a2d5-bba0ecbabff9" -modeldata '{"email": "\"test@mailinator.com\"", "password": "\"123456\""}' 
	# ./Blazemeter-run.ps1 -apikey "38e53fd821771b102b5bfddc" -apisecret "c9fb4b4be583657d952d3d25103b28590811e7b0f43bf8d7d9107b6345ae752f15a21d50" testidinput "9998412" -workspaceid "838258" -datamodelid "8df6aaaf-d1ac-56a1-a2d5-bba0ecbabff9" -modeldata '{"email": "\"test@mailinator.com\"", "password": "\"123456\"", "assertText": "\"Thank you\""}'

}


Function UpdateDataModel () {

	# Authorization generation
	$BasicAuthKey  =  $apikey  +":" +$apisecret;
	$BasicAuth = [System.Text.Encoding]::UTF8.GetBytes($BasicAuthKey);
	$AuthorizationKey = "Basic "+ [System.Convert]::ToBase64String($BasicAuth) ;
	$hdrs = @{};
	$hdrs.Add("Authorization",$AuthorizationKey);

	Write-Host "Fetching specified data model"

	# DataModel API
	$DataModelUrl = "https://tdm.blazemeter.com/api/v1/workspaces/"+$workspaceid+"/datamodels/"+$datamodelid

	# Get DataModel API call
	$ModelResponse = Invoke-RestMethod $DataModelUrl -Method GET -Headers $hdrs;

	$data = $ModelResponse | ConvertTo-Json -Depth 9;
	$jsonObj = $data | ConvertFrom-Json;
	$resultObj = $jsonObj.result | ConvertTo-Json -Depth 9;
	$resultObj = $resultObj | ConvertFrom-Json;


	# Extracting required parameters for above api response
	$id = $resultObj.id
	$title = $resultObj.title
	$description = $resultObj.description

	$entitiesTitle = $resultObj.entities.default.title

	$datasources = $resultObj.entities.default.datasources
	$datasources = $datasources | ConvertTo-Json
	if ($null -eq $datasources) {
		$datasources = "[]"
	}

	$targets = $resultObj.entities.default.targets
	$targets = $targets | ConvertTo-Json

	$props = $resultObj.entities.default.properties
	$props = $props | ConvertTo-Json

	try{
		# Converting User input object to JSON String
		$modeldata = $modeldata | ConvertFrom-Json
		$modeldata = $modeldata | ConvertTo-Json 
	} catch {
		Write-Error $_.Exception.Message;
		exit 1;
	}

$json = @"
{
    "data": {
        "type": "datamodel",
        "attributes": {
            "id": "$id",
            "kind": "tdm",
            "type": "object",
            "title": "$title",
            "schema": "http://broadcom.com/blazedata/schema",
            "entities": {
                "default": {
                    "type": "object",
                    "title": "$entitiesTitle",
                    "targets": $targets,
                    "properties": $props,
                    "datasources": $datasources,
                    "requirements": $modeldata
                }
            },
            "description": "$description"
        }
    }
}
"@

	Write-Host "Updating data model"

	# Update DataModel API call
	$ModelResponse = Invoke-RestMethod $DataModelUrl -Method Put -Headers $hdrs -Body $json -ContentType "application/json";

}
		
Function StartTest([string]$StartTestid,[string] $multitests,[string] $functionaltest)
{	
	$StartTestResponse="";
	$PublicURL="";
	$TestType="";
	try
    {			
        # if($datamodelid -ne "" -and $datamodelid -ne "0") {
        # 	UpdateDataModel;
        # }
        $TestDeatilURL = 'https://a.blazemeter.com/api/v4/tests/'+$StartTestid;
        if($modeldata -ne "{}") {
            UpdateTestDetails;
        }

        if($iterations_config -eq "true")
        {
            iterationsConfig($StartTestid);
        }

        if($multitests -eq 'true')
        {
            if($functionaltest -eq 'true')
            {
                $StartTestURL = 'https://a.blazemeter.com/api/v4/multi-tests/' +$StartTestid +'/start';
            }
            else{
                $StartTestURL = 'https://a.blazemeter.com/api/v4/multi-tests/' +$StartTestid +'/start?delayedStart=true';
            }
        }
        # elseif($functionaltest -eq 'true')
        # {
                # $StartTestURL = 'https://a.blazemeter.com/api/v4/multi-tests/' +$StartTestid +'/start';
        # }
        else
        {
            $StartTestURL = 'https://a.blazemeter.com/api/v4/tests/' +$StartTestid +'/start';
        }
        
        try {
            if($jmeterproperties -eq "null")
            {
                $StartTestResponse = Invoke-RestMethod $StartTestURL -Method POST -ContentType 'application/json' -Headers $hdrs;
            }
            else
            {
                $json = convertProperties($jmeterproperties);
                $StartTestResponse = Invoke-RestMethod $StartTestURL -Method POST -Body $json -ContentType 'application/json' -Headers $hdrs;
            }				 
            
        } 
        catch
        {				
            <# $formatstring = "{0} : {1}`n{2}`n" +
                            "    + CategoryInfo          : {3}`n" +
                            "    + FullyQualifiedErrorId : {4}`n"
            $fields = $_.InvocationInfo.MyCommand.Name,
                        $_.ErrorDetails.Message,
                        $_.InvocationInfo.PositionMessage,
                        $_.CategoryInfo.ToString(),
                        $_.FullyQualifiedErrorId

            $formatstring -f $fields
            #>
            
            
            $statuscode = $_.Exception.Response.StatusCode.value__ ;				    
            if($statuscode -eq '401')
            {
                Write-Host "Test Result: Unauthorized. Please check API Key and API Secret."; 
                Write-Host "##vso[task.complete result=Failed;]DONE";		
                exit 1;
            }
            else
            {		
                Write-Host "Unable to start the test. For more details check below error details."; 
                Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ ;
                Write-Host "Error Details:" $_.ErrorDetails.Message; 
                Write-Host "##vso[task.complete result=Failed;]DONE";		
                exit 1;						
            }
            Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ ;
            Write-Host "Error Details:" $_.ErrorDetails.Message; exit;
            
        }
            
        if($StartTestResponse -ne "")
        {
            # Write-Host "Got response"
            $data2 = $StartTestResponse | ConvertTo-Json -Depth 9;
            $jsonObj2 = $data2 | ConvertFrom-Json;
            $resultObj2 = $jsonObj2.result | ConvertTo-Json -Depth 9;
            $resultObj2 = $resultObj2 | ConvertFrom-Json;

            $sessionId=$resultObj2.sessionsId;

            $masterId=$resultObj2.id;

            Write-Host "We are working on starting your test";

            $status='';
            $completed="ENDED";
            Write-Host "Note: Starting your test takes around 2-4 minutes. Your report will appear once we have gathered the data."

            $masterURL = "https://a.blazemeter.com/api/v4/masters/"+$masterId

            # setting report name

            if($reportname -ne "null")
            {
                Write-Host "Setting report name: " $reportname

                $reportNameRequest = 
                @"
                {
                    "name" : "$reportname"
                }
"@  
                $reportNameResponse = Invoke-RestMethod $masterURL -Method PATCH -Body $reportNameRequest -ContentType 'application/json' -Headers $hdrs;

                # $reportNameData = $reportNameResponse | ConvertTo-Json -Depth 9;
                # $reportNameData1 = $reportNameData | ConvertFrom-Json;
                # $reportNameResultData1 = $reportNameData1.result | ConvertTo-Json -Depth 9;
                # $reportNameResultData1 = $reportNameResultData1 | ConvertFrom-Json;

                # $reportName = $reportNameResultData1.name;

            }

            # send notes
            if($note -ne "null")
            {
                Write-Host "Sent notes: " $note
                $noteRequest = 
                @"
                {
                    "note" : "$note"
                }
"@
                $noteResponse = Invoke-RestMethod $masterURL -Method PATCH -Body $noteRequest -ContentType 'application/json' -Headers $hdrs;

                # $noteData = $noteResponse | ConvertTo-Json -Depth 9;
                # $noteData1 = $noteData | ConvertFrom-Json;
                # $noteResultData = $noteData1.result | ConvertTo-Json -Depth 9;
                # $noteResultData = $noteResultData | ConvertFrom-Json;

                # $notes = $noteResultData.note;
            }


            #$ReportSummary = "https://a.blazemeter.com/app/#/accounts/"+$AccountID+"/workspaces/"+$WorkSpaceID+"/projects/"+$ProjectID+"/masters/"+$masterId+"/summary"
            $ReportSummary = "https://a.blazemeter.com/app/#/masters/"+$masterId
            Write-Host "Report URL: " $ReportSummary  -ForegroundColor green;


            # Internal Report URL

            # $getUserInfoUrl = "https://a.blazemeter.com/api/v4/user";
            # $UserInfoResponse = Invoke-RestMethod $getUserInfoUrl -Method GET -ContentType 'application/json' -Headers $hdrs;

            # $data = $UserInfoResponse | ConvertTo-Json -Depth 9;
            # $jsonObj = $data | ConvertFrom-Json;
            # $resultObj = $jsonObj.result | ConvertTo-Json -Depth 9;
            # $resultObj = $resultObj | ConvertFrom-Json;
            # $resultObj1 = $resultObj.defaultProject | ConvertTo-Json -Depth 9;
            # $resultObj1 = $resultObj1 | ConvertFrom-Json;
            # $accountId = $resultObj1.accountId

            # $getProjectInfoUrl = "https://a.blazemeter.com/api/v4/tests/"+$StartTestid;
            # $projectInfoResponse = Invoke-RestMethod $getProjectInfoUrl -Method GET -ContentType 'application/json' -Headers $hdrs;

            # $data1 = $projectInfoResponse | ConvertTo-Json -Depth 9;
            # $jsonObj1 = $data1 | ConvertFrom-Json;
            # $resultObj1 = $jsonObj1.result | ConvertTo-Json -Depth 9;
            # $resultObj1 = $resultObj1 | ConvertFrom-Json;
            # $projectsId = $resultObj1.projectId;

            # $getWorkspaceInfoUrl = "https://a.blazemeter.com/api/v4/projects/"+$projectsId;
            # $workspaceInfoResponse = Invoke-RestMethod $getWorkspaceInfoUrl -Method GET -ContentType 'application/json' -Headers $hdrs;

            # $data2 = $workspaceInfoResponse | ConvertTo-Json -Depth 9;
            # $jsonObj2 = $data2 | ConvertFrom-Json;
            # $resultObj2 = $jsonObj2.result | ConvertTo-Json -Depth 9;
            # $resultObj2 = $resultObj2 | ConvertFrom-Json;
            # $workspaceId = $resultObj2.workspaceId


            
            
            #Get public report URL

            # https://a.blazemeter.com/app/?public-token=XyIZHzAk3lE1RHyjpjd9i7uyCWlzC5NmZIl6lXS0bFQ4b3ROdh#/accounts/-1/workspaces/-1/projects/-1/masters/37063099/cross-browser-summary
            #[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            $GetTokenURL = 'https://a.blazemeter.com/api/v4/masters/' +$masterId +'/public-token';
            $PublicTokenResponse = "";
            try
            {

                # Get api details if test is not multi or suite. As for suite and muilti no need to find test type
                if($functionaltest -eq 'false' -and $multitests -eq 'false' )
                {
                    $TestDetailResponse ="";
                    $TestDetailResponse = Invoke-RestMethod $TestDeatilURL -Method GET -ContentType 'application/json' -Headers $hdrs;

                    if($TestDetailResponse -ne "")
                    {
                        $testdetails = $TestDetailResponse | ConvertTo-Json -Depth 9;
                        $jsonObjP1 = $testdetails | ConvertFrom-Json;
                        $resultObj11 = $jsonObjP1.result | ConvertTo-Json -Depth 9;
                        $resultObj33 = $resultObj11 | ConvertFrom-Json;
                        $TestType =  $resultObj33.configuration.type;

                        #Write-Host "Test type" $TestType ;
                    }
                }	

                # Internal Report URL display

                # $internalUrl = ""

                # if($TestType -ne "" -and  $TestType -eq 'functionalGui')
                # {
                #     $internalUrl = "https://a.blazemeter.com/app/#/accounts/"+$accountId+"/workspaces/"+$workspaceId+"/projects/"+$projectsId+"/masters/"+$masterId+"/cross-browser-summary";
                # }
                # else{
                #     $internalUrl = "https://a.blazemeter.com/app/#/accounts/"+$accountId+"/workspaces/"+$workspaceId+"/projects/"+$projectsId+"/masters/"+$masterId+"/summary";
                # }

                # Write-Host "Internal Report URL : " $internalUrl  -ForegroundColor green;

                if($TestType -ne "" -and  $TestType -eq 'functionalGui') {
                    waitForFinish($masterId)
                }
                
                $PublicTokenResponse = Invoke-RestMethod $GetTokenURL -Method POST -Headers $hdrs;
            }
            catch
            {
                
            }

            if($PublicTokenResponse -ne "")
            {
                $Publicdata = $PublicTokenResponse | ConvertTo-Json -Depth 9;
                $jsonObjP = $Publicdata | ConvertFrom-Json;
                $resultObj1 = $jsonObjP.result | ConvertTo-Json -Depth 9;
                $resultObj3 = $resultObj1 | ConvertFrom-Json;
                $publicToken =  $resultObj3.publicToken;

                $PublicURL = 'https://a.blazemeter.com/app/?public-token='+$publicToken+'#/masters/'+$masterId+'/summary'

                if($TestType -ne "" -and  $TestType -eq 'functionalGui')
                {
                    $PublicURL = 'https://a.blazemeter.com/app/?public-token='+$publicToken+'#/accounts/-1/workspaces/-1/projects/-1/masters/'+$masterId+'/cross-browser-summary'
                }
                elseif($functionaltest -eq 'true')
                {
                    $PublicURL = 'https://a.blazemeter.com/app/?public-token='+$publicToken+'#/accounts/-1/workspaces/-1/projects/-1/masters/'+$masterId+'/suite-report'
                }

                
                Write-Host "Public Report URL: " $PublicURL  -ForegroundColor green;	
                
                # Write-Host "Report URL: " $ReportSummary  -ForegroundColor green;	    
            }
            else
            {
                Write-Host "Report URL: " $ReportSummary  -ForegroundColor green;	
            }
    
            $OldStatus="";
            $output = "BlazeLogFile.txt"
            
            if($sessionId -ne "")
            {
                if($ContinuePipeline -ne "true")
                {
                    $TailLine=0;
            
                    While ($status -ne $completed)
                    {	
                        try
                        {
                                    
                            $statusURL ='https://a.blazemeter.com/api/v4/masters/' +$masterId +'/status';

                            $LogFileURL ='https://a.blazemeter.com/api/v4/sessions/' +$sessionId[0] +'/reports/logs/data';
            
                            $StatusResponse = Invoke-RestMethod $statusURL  -Method GET -ContentType 'application/json' -Headers $hdrs;

                            $StatusJSONResponse =$StatusResponse | ConvertTo-Json -Depth 9;

                            $StatusJSONFromResponse = $StatusJSONResponse | ConvertFrom-Json;

                            $resultObj1 = $StatusJSONFromResponse.result | ConvertTo-Json -Depth 9;

                            $resultObj4 = $resultObj1 | ConvertFrom-Json;

        
                            $OldStatus = $status ;
                            $status=$resultObj4.status;
                            if(	$OldStatus -ne $status)
                            {
                                Write-Host "Test Status: " $status -ForegroundColor green;		
                            }
                            if($showtaillog -eq "true")	
                            {			
                                if($status -eq "DATA_RECEIVED" -Or  $status -eq "TERMINATING" -Or  $status -eq "TAURUS BZT DONE" -Or  $status -eq "TAURUS IMAGE DONE" -Or  $status -eq "ENDED" )
                                {
            
                                    $LogResponse = Invoke-RestMethod  $LogFileURL  -Method GET -ContentType 'application/json' -Headers $hdrs;

                                    $LogJSONResponse =$LogResponse | ConvertTo-Json -Depth 9;

                                    $LogJSONFromResponse = $LogJSONResponse | ConvertFrom-Json;

                                    $resultObj5 = $LogJSONFromResponse.result | ConvertTo-Json -Depth 9;

                                    $resultObj6 = $resultObj5 | ConvertFrom-Json;
                                    $DataLogFileURL="";

                                    For ($i=0; $i -lt $resultObj6.Length; $i++) {
                                        if($fileName=$resultObj6[$i].filename -eq "bzt.log")
                                        {
                                            $DataLogFileURL =$resultObj6[$i].dataUrl	;	  				  
                                            # $RedFileWebResponse= Invoke-RestMethod $DataLogFileURL
                                            # Write-Host $RedFileWebResponse;
            
                                            Start-Sleep -Seconds 10;    
                                            Invoke-WebRequest -Uri $DataLogFileURL -OutFile $output	

                                            $Line = Get-Content $output | Measure-Object -Line
                            
            
                                            $AllLines = $Line.Lines;
            
                                            if($AllLines -gt $TailLine){	
                                                $WaitMsgShown = "true"				
                                                $NewTailLine=$AllLines - $TailLine	;
                                                $TailLine = $AllLines	
                                
                                                Get-Content  -Path $output  -Tail $NewTailLine
                                                Write-Host "Please wait we are gathering your data..." -ForegroundColor yellow;	
                                            }
                                        }
                                    }

                                }
        
                            }
                    


                        }
                        catch{}
                    }

                    # Execute download artifacts api
                    For ($i=0; $i -lt $sessionId.Length; $i++) { 
                       DownloadArtifacts $sessionId[$i];
                    }

                    try
                    {
                        #Write-Host "Waiting for Status  -------"
                        Start-Sleep -Seconds 10; 
                        #$ThresholdURL = 'https://a.blazemeter.com/api/v4/masters/' +$masterId +'/reports/thresholds';
                
                        $ThresholdURL = 'https://a.blazemeter.com/api/v4/masters/' +$masterId ;
                        
                        $ThresholdResponse = Invoke-RestMethod $ThresholdURL -Method GET -ContentType 'application/json' -Headers $hdrs;
                        #Write-Host "TEST STATUS URL ------------" $ThresholdURL ;	
                        #Write-Host "Report URL: " $ReportSummary  -ForegroundColor green;
                        $StatusJSONResponse1 =$ThresholdResponse | ConvertTo-Json -Depth 9;

                        $StatusJSONFromResponse1 = $StatusJSONResponse1 | ConvertFrom-Json;

                        $resultObj2 = $StatusJSONFromResponse1.result | ConvertTo-Json -Depth 9;

                        $resultObj5 = $resultObj2 | ConvertFrom-Json;

                        #Write-Host "Satus -----------" 	$resultObj5
                        $APIStatus =  $resultObj5.passed;
                        $hasData = $resultObj5.hasData;

                        # set json result for github pipeline
                        $summary = getSummaryData($masterId)
                        
                        $status = "success"

                        if($hasData -eq $true)
                        {
                            if($APIStatus -eq $true)
                            {
                                $status = "success"
                            }
                            ElseIf($APIStatus -eq $false)
                            {
                                $status = "failed"
                            }
                            else{
                                $status = "success"
                            }
                        }
                        else
                        {
                            $status = "failed";
                        }
                        
                        $resultData = @{};
                        $resultData.Add("internalUrl",$ReportSummary)
                        $resultData.Add("publicUrl",$PublicURL)
                        $resultData.Add("status",$status)
                        $summary = $summary | ConvertFrom-Json;
                        $resultData.Add("summary",$summary)
                        $results = $resultData | ConvertTo-Json -Depth 9;
                        Set-Content -Path results -Value $results
                        
                        if($hasData -eq $true)
                        {
                            #Write-Host "API STATUS " $APIStatus
                            if($APIStatus -eq $true -Or ($createtest -eq "true"))
                            {
                                #[System.Windows.Forms.MessageBox]::Show("Found")
                                Write-Host "Test Execution Done." -ForegroundColor green;
                            }
                            ElseIf($APIStatus -eq $false)
                            {
                                Write-Host "Test failed because one or more failure conditions are met.";
                                
                                if($ignoreSLA -ne "true")
                                {
                                    Write-Host "##vso[task.complete result=Failed;]DONE";
                                    exit 1;	
                                }
                                	
                                #Write-Host "Test Failed"										
                                #[System.Windows.Forms.MessageBox]::Show("NOT Found")
                            }
                            else{
                                Write-Host "##vso[task.complete result=Succeeded;]DONE";
                                #Write-Host "Test Succeeded"
                                # exit 1;	
                            }
                        }
                        else
                        {
                            Write-Host "Test failed because one or more failure conditions are met.";
                            if($ignoreSLA -ne "true")
                            {
                                Write-Host "##vso[task.complete result=Failed;]DONE";
                                exit 1;	
                            }
                        }
                    }
                    catch{
                                
                        $statuscode = $_.Exception.Response.StatusCode.value__ ;
                        if($statuscode -eq '401')
                        {
                            #Write-Error "Test Result: Unauthorized. Please check API Key and API Secret.";
                            Write-Host "Test Result: Unauthorized. Please check API Key and API Secret.";
                            Write-Host "##vso[task.complete result=Failed;]DONE";		
                            exit 1;	
                                            
                        }
                        else{					 
                            #Write-Error "Error in updating test. For more details check below error details."
                            Write-Host "Error in updating test. For more details check below error details.";
                            Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ ;
                            Write-Host "Error Details:" $_.ErrorDetails.Message; 
                            Write-Host "##vso[task.complete result=Failed;]DONE";		
                            exit 1;	
                        }					
                            
                        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
                        Write-Host "Error Details:" $_.ErrorDetails.Message; exit;
                    }
                }
            }
            else
            {
                Write-Host "Un Authorization";
            }    
        }
        else
        {			        
            Write-Host "Unable to start the test. For more details check below error details.";  
            Write-Host "##vso[task.complete result=Failed;]DONE";		
            exit 1;	
        }
                
                
    }
    Catch
    {
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Error Details:" $_.ErrorDetails.Message	; exit;
    }	

    try
    {
        Set-Content -Path $output -Value $_
    }	
    catch
    {}		

}	


Function CheckIfFileUploadedOrNot([string]$Testid)
{
	#Write-Host "Checking test files uploaded or not.";
	$ValidateFile="";
    $resultObj4="";
    try
    {
        $ValidateFileURL= "https://a.blazemeter.com/api/v4/tests/"+$Testid+"/files"
        $ValidateFile = Invoke-RestMethod $ValidateFileURL -Method GET -ContentType 'application/json' -Headers $hdrs;
    }
    catch
    {
        $statuscode = $_.Exception.Response.StatusCode.value__ ;
        if($statuscode -eq '401')
        {
            Write-Host "Test Result: Unauthorized. Please check API Key and API Secret."; 
            Write-Host "##vso[task.complete result=Failed;]DONE";	
            exit 1;	
                            
        }
        else{	
                Write-Host "Error in updating test. For more details check below error details."; 
                Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
                Write-Host "Error Details:" $_.ErrorDetails.Message;
                Write-Host "##vso[task.complete result=Failed;]DONE";		
                exit 1;						
        }					
                        
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Error Details:" $_.ErrorDetails.Message; exit;
    }	
			
    $data4 = $ValidateFile | ConvertTo-Json -Depth 9;
    $jsonObj4 = $data4 | ConvertFrom-Json;
    $resultObj4 = $jsonObj4.result | ConvertTo-Json -Depth 9;
    $resultObj4 = $resultObj4 | ConvertFrom-Json;
    
    if(-not [string]::IsNullOrEmpty($resultObj4 ))
    {
        Write-Host "Test file(s) uploaded successfully.";
        return "true";
    }
    else
    { 
        Write-Host "Test file(s) not found.";
        return "false";
    }
					
}

Function DownloadArtifacts($sessionId) {	
    try {	
        $ArtifactsUrl = "https://a.blazemeter.com/api/v4/sessions/" + $sessionId + "/reports/logs";	
        $ArtifactsResponse = Invoke-RestMethod $ArtifactsUrl -Method GET -Headers $hdrs;	
        $data = $ArtifactsResponse | ConvertTo-Json -Depth 9;	
        $jsonObj = $data | ConvertFrom-Json;	
        $resultObj = $jsonObj.result | ConvertTo-Json -Depth 9;	
        $resultObj = $resultObj | ConvertFrom-Json;	
        $artifactsData = $resultObj.data[0] | ConvertTo-Json;	
        $artifactsData = $artifactsData | ConvertFrom-Json;	
        $artifactsDownloadUrl = $artifactsData.dataurl;	
        Write-Host "Artifacts URL : " $artifactsDownloadUrl -ForegroundColor green;	

        Write-Host "Downloading artifacts at ./tmp/artifacts/"	
        $currentDate = Get-Date -Format "MM/dd/yyyy_HH:mm"
        mkdir -p tmp/artifacts;
        $destination = "./tmp/artifacts/"+$sessionId+"-artifacts.zip";	
        Invoke-WebRequest -Uri $artifactsDownloadUrl -OutFile $destination
        # Start-Process $artifactsDownloadUrl;
    }	
    catch {	
        Write-Host "Error in downloading artifacts..."					
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__
        Write-Host "Error Message:" $_.Exception.Message 	
        Write-Host "Error Details:" $_.ErrorDetails.Message; 	
    }	
    # Run existing and Download
    # ./Blazemeter-run.ps1 -testid 10129962 -ContinuePipeline false -showtaillog false -apikey 38e53fd821771b102b5bfddc -apisecret c9fb4b4be583657d952d3d25103b28590811e7b0f43bf8d7d9107b6345ae752f15a21d50	
    # Create Test and Download	
    # ./Blazemeter-run.ps1 -createtest true -testname "CreateDownloadTest" -projectid 961236 -inputstartfile "BlazeDemo.yaml" -ContinuePipeline false -showtaillog false -apikey 38e53fd821771b102b5bfddc -apisecret c9fb4b4be583657d952d3d25103b28590811e7b0f43bf8d7d9107b6345ae752f15a21d50 	
}	

Function UpdateYaml($yamlfile) {
    # updating parameter in yml
    try {
        if($env_variable -ne "{}") {
           Write-Host "Updating Yaml: $yamlfile"
           [psobject]$credsObj = $env_variable | ConvertFrom-Json
           $content = Get-Content -Path $yamlfile -Raw
           
           foreach ($props in $credsObj.psobject.properties) {
                $key = $props.Name
                $val = $props.Value
                $regex = "[a-zA-Z0-9'`"{}#@$%&*!-_]*"
                $matchText = $key+": "+$regex
                $valueText = $key+": "+$val
            
                $content = $content -replace $matchText, $valueText
            }
           
           Set-Content -Path $yamlfile -Value $content
       }
    } catch {
        Write-Host "Error in updating yaml file: $yamlfile"		
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 	
        Write-Host "Exception Message:" $_.Exception.Message
        Write-Host "Error Details:" $_.ErrorDetails.Message; 
    }

#    ./Blazemeter-run.ps1 -testid "10264306" -Uploadfilechk "true" -inputallfiles "BlazeDemo.yaml" -env_variable '{"username":"dnyanesh","password":"123"}' -apikey "38e53fd821771b102b5bfddc" -apisecret "c9fb4b4be583657d952d3d25103b28590811e7b0f43bf8d7d9107b6345ae752f15a21d50"
}

Function convertProperties([string]$sessionProperties)
{
    Write-Host "Added Jmeter properties:" $sessionProperties; 
    $propertiesArray = $sessionProperties.Split(",");
    $sessionPropertiesArray = @();
    foreach($array in $propertiesArray)
    {
        $propertiesObject = @{};
        $arrayobject = $array.Split("=");
        if($arrayobject.length -gt 1)
        {
            $propertiesObject.Add("key",$arrayobject[0]);
            $propertiesObject.Add("value",$arrayobject[1]);
        }
        $sessionPropertiesArray = $sessionPropertiesArray + $propertiesObject;
    }
    
    $propData = $sessionPropertiesArray | ConvertTo-Json -Depth 9

    $plugins = @{};
    $plugins.Add("remoteControl",$sessionPropertiesArray);

    $configuration = @{};
    $configuration.Add("plugins",$plugins);
    $configuration.Add("enableJMeterProperties","true");

    $data = @{};
    $data.Add("configuration",$configuration);

    $request = @{};
    $request.Add("data",$data);    
    
    $convertJSONData = $request | ConvertTo-Json -Depth 9

#     $json = 
#     @"
#     {
#         "data": {
#             "configuration": 
#             {
#                 "plugins": 
#                 {
#                     "remoteControl": 
#                     [
#                         {
#                             "key" : "test",
#                             "value": "test123"
#                         }
#                     ]
#                 },
#                 "enableJMeterProperties": "true"
#             }
#         }
#     }
# "@  

    return $convertJSONData;
}
	
	
Function UpdateTest([string]$testid)
{
	try{
        # [System.Windows.Forms.MessageBox]::Show($testid);

        #Write-Host "Uploading file for testid: " $testid;
        #Write-Host "Auth key in Function " $AuthorizationKey;
        
        $UpdateTestURL = 'https://a.blazemeter.com/api/v4/tests/'+$testid+'/files';
                                        
        try
        { 
            # Create a web client object
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("Authorization", $AuthorizationKey)							
            # We are redirecting to null here because web client has a little output bug where it sometimes puts some garbage
            # characters on the screen.  This has no impact on the fidelity of the copy.

            $fileExt = "";
            $fileName = "";
            
            if($inputstartfile -ne 'null')
            {
                $fileExt = [System.IO.Path]::GetExtension($inputstartfile);
                $fileName = Split-Path $inputstartfile -leaf
            }

            if($createtest -eq "true" -or $inputstartfile -ne 'null')
            {      
                if($createtest -eq "false")
                { 
                    $updatestartfilenameURL = 'https://a.blazemeter.com/api/v4/tests/'+$testid;

                    if($fileExt -ine ".jmx" -or   $fileExt -ine ".yml" -or  $fileExt -ine ".yaml")
                    {
                        $scriptType = "jmeter";
                        $testMode = ""

                        if($fileExt -ieq ".yml" -or  $fileExt -ieq ".yaml")
                        {
                            $scriptType = "taurus";
                            $testMode = "script";
                        }

                        $json =
                        @"
                        {
                            "configuration":
                            {
                                "filename" : "$fileName",
                                "scriptType" : "$scriptType",
                                "testMode": "$testMode"
                            }
                        }
"@
                        $startfilenameResponse = Invoke-RestMethod $updatestartfilenameURL -Method PATCH -Body $json -ContentType 'application/json' -Headers $hdrs;
                    }
                    else{
                        Write-Host "We currently support JMeter and Taurus test creation. Please upload JMX or YAML file."; 
                        Write-Host "##vso[task.complete result=Failed;]DONE";		
                        exit 1;
                    }
                }

                Write-Host "Uploading test start file " $inputstartfile
                UpdateYaml $inputstartfile;
                # $wc.UploadFile($UpdateTestURL,"./"+$inputstartfile) > $null;		
                $wc.UploadFile($UpdateTestURL, $inputstartfile) > $null;		      
            }
            if($Uploadfilechk -eq "true" -and $inputallfiles -ne 'null')
            {
                $DependantTestfiles = Get-ChildItem -Path $inputallfiles -Force -Recurse  -file 
                for ($i=0; $i -lt $DependantTestfiles.Count; $i++) {
                    $fileExt = [System.IO.Path]::GetExtension($DependantTestfiles[$i].FullName);
                    if($fileExt -eq ".yml" -or $fileExt -eq ".yaml") {
                        UpdateYaml $DependantTestfiles[$i].FullName;
                    }
                    Write-Host "Uploading test dependant file " $DependantTestfiles[$i].FullName
                    $wc.UploadFile($UpdateTestURL,""+$DependantTestfiles[$i].FullName) > $null;		
                }
            }

            if($createtest -eq "false" -and $inputstartfile -ne 'null')
            {
                $startfilevalidateUrl = 'https://a.blazemeter.com/api/v4/tests/'+$testid+'/validate'
                $json = 
                @"
                {
                    "files": [
                        {
                            "fileName": "$fileName"
                        }
                    ],
                    "performDataMerge": false
                }
"@
                $startfilevalidateResponse = Invoke-RestMethod  $startfilevalidateUrl -Method POST -Body $json -ContentType 'application/json' -Headers $hdrs;
            }

            #Write-Host "Test files uploaded successfully."
        }
        catch
        {		
            $statuscode = $_.Exception.Response.StatusCode.value__ ;
            if($statuscode -eq '401')
            {					 
                Write-Host "Test Result: Unauthorized. Please check API Key and API Secret."; 
                Write-Host "##vso[task.complete result=Failed;]DONE";		
                exit 1;					
            }
            else{					 					 
                Write-Host "Error in updating test. For more details check below error details."; 
                Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
                Write-Host "Exception Details:" $_.Exception.Message;
                Write-Host "Error Details:" $_.ErrorDetails.Message;
                Write-Host "##vso[task.complete result=Failed;]DONE";	
                exit 1;
            }					
                            
            Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "Error Details:" $_.ErrorDetails.Message; exit;	
        }
				
				
    }
    catch
    {				
        Write-Host "Error in updating test. Please contact to administrator."				
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Error Details:" $_.ErrorDetails.Message; 
        Write-Host "##vso[task.complete result=Failed;]DONE";		
        exit 1;
    }
		
}

function iterationsConfig([string]$testid)
{
   
    $iterationsConfigURL = 'https://a.blazemeter.com/api/v4/tests/'+$testid;

    try
    { 

        $testDetails = Invoke-RestMethod $iterationsConfigURL -Method GET -Headers $hdrs;

        $data = $testDetails | ConvertTo-Json -Depth 9;	
        $jsonObj = $data | ConvertFrom-Json;
        $resultObj = $jsonObj.result | ConvertTo-Json -Depth 9;	
        $resultObj = $resultObj | ConvertFrom-Json;	

        $configuration = $resultObj.configuration | ConvertTo-Json -Depth 9
        $configuration = $configuration | ConvertFrom-Json
        $scriptType = $configuration.scriptType

        if($scriptType -eq "jmeter")
        {
            $overrideExecutionsdata = $resultObj.overrideExecutions[0] | ConvertTo-Json -Depth 9;
            $overrideExecutionsdata = $overrideExecutionsdata | ConvertFrom-Json;	

            $concurrency = $overrideExecutionsdata.concurrency;
            $executor = $overrideExecutionsdata.executor;
            $rampUp = $overrideExecutionsdata.rampUp;
            $steps = $overrideExecutionsdata.steps;
            $locations = $overrideExecutionsdata.locations | ConvertTo-Json -Depth 9;
            $locationsPercents = $overrideExecutionsdata.locationsPercents | ConvertTo-Json -Depth 9;
        

            $json = @"
            {
                "overrideExecutions" :
                [
                    {
                        "concurrency": $concurrency,
                        "executor": "$executor",
                        "rampUp": "$rampUp",
                        "steps": $steps,
                        "iterations": $iterations,
                        "locations": $locations,
                        "locationsPercents": $locationsPercents
                    }
                ]
            }
"@
            $iterationsConfigResponse = Invoke-RestMethod $iterationsConfigURL -Method PUT -Body $json -ContentType 'application/json' -Headers $hdrs;

            # $data1 = $iterationsConfigResponse  | ConvertTo-Json -Depth 9;
            # $jsonObj1 = $data1 | ConvertFrom-Json;
            # $resultObj1 = $jsonObj1.result | ConvertTo-Json -Depth 9;	
            # $resultObj1 = $resultObj1 | ConvertFrom-Json;	

            # $configuration1 = $resultObj.overrideExecutions[0] | ConvertTo-Json -Depth 9

            # Write-Host "iterationsConfigResponse : " $configuration1
        }
    }
    catch
    {
        Write-Host "Error in updating test iterations configure. Please contact to administrator."
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Error Details:" $_.ErrorDetails.Message; 
        Write-Host "##vso[task.complete result=Failed;]DONE";		
        exit 1;	
    }

}

function getSummaryData([string]$masterId)
{
    $summaryUrl = "https://a.blazemeter.com/api/v4/masters/"+$masterId+"/reports/default/summary"
    try
    { 
        
        $summaryDetails = Invoke-RestMethod $summaryUrl -Method GET -Headers $hdrs;

        $data = $summaryDetails | ConvertTo-Json -Depth 9;	
        $jsonObj = $data | ConvertFrom-Json;
        $resultObj = $jsonObj.result | ConvertTo-Json -Depth 9;	
        $resultObj = $resultObj | ConvertFrom-Json;

        $summary = $resultObj.summary[0] | ConvertTo-Json -Depth 9;

        if($summary -ne "null")
        {
            Write-Host "Test summary "  $summary
        }
        return $summary
    }
    catch{
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Error Details:" $_.ErrorDetails.Message; 
    }
}

function Is-Numeric ($Value) {
    return $Value -match "^[\d]+$"
}


# test run by passing test name
function getTestIdbyTestName()
{
    $testDetailsURL = "";

    if($projectid -eq "" -or $projectid -eq "0")
    {
        Write-Host "Please pass project id to start the test.";
        Write-Host "##vso[task.complete result=Failed;]DONE";		
        exit 1;
    }
    elseif($testname -eq "" -or $testname -eq "0")
    {
        Write-Host "Please pass testname to start the test.";
        Write-Host "##vso[task.complete result=Failed;]DONE";	
        exit 1;
    }
    else{
        if($multitests -eq 'true')
        {
            if($functionaltest -eq 'true')
            {
                $testDetailsURL = "https://a.blazemeter.com/api/v4/multi-tests?projectId="+$projectid+"&name="+$testname+"&platform=functional";
            }
            else
            {
                $testDetailsURL = "https://a.blazemeter.com/api/v4/multi-tests?projectId="+$projectid+"&name="+$testname;
            }
        }
        else
        {
            $testDetailsURL = "https://a.blazemeter.com/api/v4/tests?projectId="+$projectid+"&name="+$testname;
        }
    }

    try
    { 

        $testDetailsUrlResponse = Invoke-RestMethod $testDetailsURL -Method GET -Headers $hdrs; 

        $data = $testDetailsUrlResponse | ConvertTo-Json -Depth 9;
        $jsonObj = $data | ConvertFrom-Json;
        $resultObj = $jsonObj.result | ConvertTo-Json -Depth 9; 
        $resultObj1 = $resultObj | ConvertFrom-Json;

        if($resultObj1.Length -gt 1)
        {
            Write-Host "More than one test are available in the same test name";
            Write-Host "##vso[task.complete result=Failed;]DONE";		
            exit 1;
        }
        else
        {
            return $resultObj1.id
        }
 
    }
    catch{
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Error Details:" $_.ErrorDetails.Message; 
    }
}
	
# Write-Host " inputfile" $inputstartfile
# Write-Host " apikey" $apikey;
# Write-Host " apisecret" $apisecret;
# Write-Host " testurl" $testurl;
# Write-Host " showtaillog" $showtaillog;
# Write-Host " createtest" $createtest
# Write-Host " testname" $testname;
# Write-Host " inputallfiles" $inputallfiles
# Write-Host " projectid" $projectid ;
# Write-Host " totalusers" $totalusers ;

$StartFileName ="";
$TestID = 0;
# $fileExt = [System.IO.Path]::GetExtension($inputfile);
# $isValidExt =  $fileExt -eq ".jmx"	 

try
{ 
	$CreateTestResponse="";
	$BasicAuthKey  =  $apikey  +":" +$apisecret;
	$BasicAuth = [System.Text.Encoding]::UTF8.GetBytes($BasicAuthKey);
	$AuthorizationKey = "Basic "+ [System.Convert]::ToBase64String($BasicAuth) ;
	$hdrs = @{};
	$hdrs.Add("Authorization",$AuthorizationKey);
	 
   
	#$Testid = 0;
	if($createtest -eq "true" )
	{	  
        $testurl ="";

        #Write-Host "In create Test"
        $CreateTestURL = "https://a.blazemeter.com/api/v4/tests";
	 
        
        if( $totalusers -eq "" -or  $duration -eq "")
        {
            $totalusers = 20; $duration =20;
        }
        if( $rampup -eq "" )
        {
            $rampup = 1; 
        }
	 
        $fileExt = [System.IO.Path]::GetExtension($inputstartfile);
        $isValidExt =  $fileExt -eq ".jmx"	
        $IsValidTotalUsers = Is-Numeric $totalusers ;
        $IsValidDuration = Is-Numeric $duration ;
        $IsValidRamup = Is-Numeric $rampup ;
        
	 
        if( $fileExt -eq "" )
        {		
            Write-Host "Please upload start file for test."; 
            Write-Host "##vso[task.complete result=Failed;]DONE";		
            exit 1;
        }
        elseif( $fileExt -ine ".jmx" -and   $fileExt -ine ".yml" -and  $fileExt -ine ".yaml" )
        {		
            Write-Host "We currently support JMeter and Taurus test creation. Please upload JMX or YAML file."; 
            Write-Host "##vso[task.complete result=Failed;]DONE";		
            exit 1;
        }
        elseif( $IsValidTotalUsers -ne $True )
        {
            Write-Host "Invalid total users count."; 
            Write-Host "##vso[task.complete result=Failed;]DONE";		
            exit 1;
        }
        elseif( $IsValidDuration -ne $true )
        {
            Write-Host "Invalid total users count." ; 
            Write-Host "##vso[task.complete result=Failed;]DONE";		
            exit 1;
        }
        elseif($IsValidRamup -ne $true )
        {
            Write-Host "Invalid total users count." ; 
            Write-Host "##vso[task.complete result=Failed;]DONE";		
            exit 1;
        }
        else
	    {
            #Write-Host "Found JMX file"
            $duration = $duration - $rampup;
            $duration =  """$duration m""" -replace (' ')
            $rampup = """$rampup m"""  -replace (' ')
			
			#Write-Host " rampup" $rampup ;
			#Write-Host " duration" $duration ;
		
            #Write-Host "Found JMX file"
            #Write-Host "Creating new test."
		
            $StartFileName = Split-Path $inputstartfile -leaf
            $ScriptType = "jmeter";

            if($fileExt -ieq ".yml" -or  $fileExt -ieq ".yaml")
            {
                $ScriptType = "taurus";
            }

	        $json="";
	  
	   
	        Write-Host "Test script type: " $ScriptType
            if($projectid -ne "" )	 
	        {

                if($ScriptType -eq "jmeter" )
	            {
	   $json = @"
	   {
		"projectId": $projectid ,
		"configuration": {
            "type": "taurus",
			 "filename": "$StartFileName",
			  "scriptType": "$ScriptType",
            "canControlRampup": false,
            "targetThreads": 275,
            "executionType": "taurusCloud",
            "enableFailureCriteria": true,
            "threads": 275,
            "testMode": "",
            "plugins": {
                "jmeter": {
                    "version": "auto",
                    "consoleArgs": "",
                    "enginesArgs": ""
                },
                "thresholds": {
                     "thresholds": [],
                    "ignoreRampup": false,
                    "slidingWindow": false
                }
            }
        },
		"shouldSendReportEmail": false,
        "overrideExecutions": [
            {
                "concurrency": $totalusers,
                "executor": "",
                "holdFor": $duration  ,
                "locations": {
                    "us-east4-a": $totalusers
                },
                "locationsPercents": {
                    "us-east4-a": 100
                },
                "rampUp": $rampup,
                "steps": 0
            }
        ],
   
		"name": "$testname"
}
"@
			
                }
                else
                {
	 $json = @"
	   {
	"projectId": $projectid,
	"configuration": {
            "type": "taurus",
            "dedicatedIpsEnabled": false,
            "canControlRampup": false,
            "targetThreads": 275,
            "executionType": "taurusCloud",
            "enableFailureCriteria": false,
            "enableMockServices": false,
            "enableTestData": false,
            "enableLoadConfiguration": true,
            "scriptType": "taurus",
            "threads": 275,
            "filename": "$StartFileName",
            "testMode": "script",
            "extraSlots": 0,
            "plugins": {
                "jmeter": {
                    "version": "auto",
                    "consoleArgs": "",
                    "enginesArgs": ""
                },
                "thresholds": {
                    "thresholds": [],
                    "ignoreRampup": false,
                    "fromTaurus": false,
                    "slidingWindow": false
                }
            }
        },
     "shouldSendReportEmail": false,
        "overrideExecutions": [],
   
		"name": "$testname"
		}
"@
	            }

            }
            else
            {
		  
		        if($ScriptType -eq "jmeter" )
	            {
	   $json = @"
	   {
		"projectId": null ,
		"configuration": {
            "type": "taurus",
			 "filename": "$StartFileName",
			  "scriptType": "$ScriptType",
            "canControlRampup": false,
            "targetThreads": 275,
            "executionType": "taurusCloud",
            "enableFailureCriteria": true,
            "threads": 275,
            "testMode": "",
            "plugins": {
                "jmeter": {
                    "version": "auto",
                    "consoleArgs": "",
                    "enginesArgs": ""
                },
                "thresholds": {
                     "thresholds": [],
                    "ignoreRampup": false,
                    "slidingWindow": false
                }
            }
        },
		"shouldSendReportEmail": false,
        "overrideExecutions": [
            {
                "concurrency": $totalusers,
                "executor": "",
                "holdFor": $duration  ,
                "locations": {
                    "us-east4-a": $totalusers
                },
                "locationsPercents": {
                    "us-east4-a": 100
                },
                "rampUp": $rampup,
                "steps": 0
            }
        ],
   
		"name": "$testname"
}
"@
	            }
                else
                {
	 $json = @"
	   {
	"projectId": null,
	"configuration": {
            "type": "taurus",
            "dedicatedIpsEnabled": false,
            "canControlRampup": false,
            "targetThreads": 275,
            "executionType": "taurusCloud",
            "enableFailureCriteria": false,
            "enableMockServices": false,
            "enableTestData": false,
            "enableLoadConfiguration": true,
            "scriptType": "taurus",
            "threads": 275,
            "filename": "$StartFileName",
            "testMode": "script",
            "extraSlots": 0,
            "plugins": {
                "jmeter": {
                    "version": "auto",
                    "consoleArgs": "",
                    "enginesArgs": ""
                },
                "thresholds": {
                    "thresholds": [],
                    "ignoreRampup": false,
                    "fromTaurus": false,
                    "slidingWindow": false
                }
            }
        },
     "shouldSendReportEmail": false,
        "overrideExecutions": [],
   
		"name": "$testname"
		}
"@
	            }

		    }
            #Write-Host "Input to Test " $json
            try
            { 
                #[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $CreateTestResponse = Invoke-RestMethod  $CreateTestURL -Method Post -Body $json -ContentType 'application/json' -Headers $hdrs; 
                Write-Host "Test:" """$testname""" "created successfully."
            }
            catch
            {
                $statuscode = $_.Exception.Response.StatusCode.value__ ;
                if($statuscode -eq '401')
                {
                    Write-Host "Test Result: Unauthorized. Please check API Key and API Secret."; 
                    Write-Host "##vso[task.complete result=Failed;]DONE";		
                    exit 1;						 					
                }
                else
                {					    					
                    Write-Host "Unable to start the test. For more details check below error details."; 
                    Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
                    Write-Host "Error Details:" $_.ErrorDetails.Message;
                    Write-Host "##vso[task.complete result=Failed;]DONE";		
                    exit 1;
                }
                Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
                Write-Host "Error Details:" $_.ErrorDetails.Message; exit;
	    	}
	
		    if($CreateTestResponse -ne "")
		    {   
                #Write-Host "Test Created."
                $data = $CreateTestResponse | ConvertTo-Json -Depth 9;
                $jsonObj = $data | ConvertFrom-Json;
                $resultObj = $jsonObj.result | ConvertTo-Json -Depth 9;
                $resultObj3 = $resultObj | ConvertFrom-Json;
                $TestID = $resultObj3.id;
                $Isvalidfile = "true"
                if($TestID -gt 0)
                {
                    Write-Host "Test id for $testname is:" $TestID;
                    #Write-Host "Updating the test"
                    #Start-Sleep -Seconds 20; 
                    #Write-Host "Waited for 20 sec"			
                    if($inputallfiles -ne "null" -or $inputstartfile -ne "null")
                    { 
                        # Write-Host "Updating the test" + $inputallfiles
                        UpdateTest $TestID;
                        $Isvalidfile = CheckIfFileUploadedOrNot $TestID;
                        if($Isvalidfile -eq "true")
                        {
                            StartTest	$TestID "false";
                        }
                        else
                        {
                            Write-Host "Unable to start the test. Check Uploaded file."; 
                            Write-Host "##vso[task.complete result=Failed;]DONE";		
                            exit 1;
                        }
                    }
                    else
                    {			 
                        StartTest	$TestID "false";
                    }
                }
		    }
            else
            {
                Write-Host "Error in starting the test. Please contact to administrator."		; 
                Write-Host "##vso[task.complete result=Failed;]DONE";		
                exit 1;
            }
		
        }   
	  	  		
	}
	else
	{
		#$uri = $testurl -as [System.URI]
		#$checkValidURL = $uri.AbsoluteURI -ne $null -and $uri.Scheme -match '[http|https]';
		#$GetNumberfromURL  =  $testurl -replace '\D+(\d+)','$1 ';		      
		#$GetIDFromURL = $GetNumberfromURL.split(' ');
		#$AccountID = $GetIDFromURL[0];
		#$WorkSpaceID = $GetIDFromURL[1];
		#$ProjectID = $GetIDFromURL[2];

        if($testRunByTestName -eq "true")
        {
            $TestID = getTestIdbyTestName
        }
        else{
            $TestID = $testidinput;
        }

		# $multitests="false";
		# $functionaltest="false";
		#$isNUMAccountID =  Is-Numeric $AccountID;
		#$isNUMWorkSpaceID  =  Is-Numeric $WorkSpaceID ;
		#$isNUMProjectID =  Is-Numeric $ProjectID;
		$isNUMTestID  =  Is-Numeric $TestID ;
		#Write-Host "Found Test URL"
		# if($testurl -eq '' )
		# {	  		  
		  # Write-Host "Enter Test URL."; 
	      # Write-Host "##vso[task.complete result=Failed;]DONE";		
	      # exit 1;
		# }
		# elseif($inputfile -ne "" -and $fileExt -ne "" -and $isValidExt -ne $true )
	    # {		
		# Write-Error "Please upload only JMX file."
	    # }
		# elseif($checkValidURL -ne $true )
		# {	  
		  # Write-Host "Invalid Test URL.";	  
		  # Write-Host "##vso[task.complete result=Failed;]DONE";		
	      # exit 1;
		# }
		# else
		if(($apikey -eq '$(APIKEY)') -Or ($apikey -eq '$(APISECRET)') )
		{
		  #Write-Host "Please set variable group. Refer this link to create group 'https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml'"
		  Write-Host "Please set variable group. Refer this link to create group 'https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml'" 
		  Write-Host "##vso[task.complete result=Failed;]DONE";		
	      exit 1;
		}
		elseif([string]::IsNullOrEmpty($TestID) -eq $true)
		{
		   Write-Host "Unable to start the test. Please check the Test ID.";  
		   Write-Host "##vso[task.complete result=Failed;]DONE";		
	       exit 1;
		}
		elseif($isNUMTestID -ne $true)
		 {
		    Write-Host "Unable to start the test. Please check the Test ID.";  
		    Write-Host "##vso[task.complete result=Failed;]DONE";		
	        exit 1;
		}		
		else
		{
            # if($testurl -like "*multi-tests*" )
			# {
		     	# $multitests="true"
			# }
            # if($testurl -like "*functional-suite*" )
			# {
		     	# $functionaltest="true"
			# }			
			if($Uploadfilechk -eq "true" )
			{ 
				Write-Host "Test Started- Found Valid file" +$Uploadfilechk
				UpdateTest $TestID;
                $Isvalidfile = CheckIfFileUploadedOrNot $TestID;
                if($Isvalidfile -eq "true")
                {
                    Write-Host "Test Started- Found Valid file"
                    StartTest	$TestID $multitests $functionaltest;
                }
                else
                {
                    Write-Host "Unable to start the test."
                }
			}
			else
			{			 
			    StartTest $TestID $multitests $functionaltest;
			}
			
		}
	}
}
catch
{
    $statuscode = $_.Exception.Response.StatusCode.value__ ;					
    if($statuscode -eq '401')
    {
        Write-Host "Test Result: Unauthorized. Please check API Key and API Secret."; 
        Write-Host "##vso[task.complete result=Failed;]DONE";		
        exit 1;	
                        
    }
    else
    {					    
        Write-Host "Unable to start the test. For more details check below error details."
        Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "Error Details:" $_.ErrorDetails.Message;
        Write-Host "##vso[task.complete result=Failed;]DONE";		
        exit 1;
    }
    Write-Host "Error Code:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "Error Details:" $_.ErrorDetails.Message; exit;
}
	