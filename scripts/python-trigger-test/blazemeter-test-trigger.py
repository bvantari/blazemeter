#!/usr/bin/env python
# -*- coding: utf-8 -*-
# script to trigger a test and send a file when needed to be executed.
# to execute the script you can call it as: #20200413 5:56pm
# help:
# python blazemeter-test-trigger.py -h
#  --testid TESTID, -t TESTID
#                        Test ID
#  --keysecret KEYSECRET, -k KEYSECRET
#                        Base64 Key:Secret
#  --sleepTime SLEEPTIME, -s SLEEPTIME
#                        Sleep Time for checking status (default each 30s)
# with mandatory params:
# python blazemeter-test-trigger.py -t <testid> -k <base64 key:secret>
#
# optional params:
# python blazemeter-test-trigger.py -t <testid> -k <base64 key:secret> -s <sleep time> -f <filename to be injected> -d <destination path for the file>

import requests
import time
import os
import sys
import argparse
 
def main():
    keySecret=""
    testId=""
    sleepTime="30"

    parser = argparse.ArgumentParser(description='BlazeMeter test trigger script')
    parser.add_argument('--testid', "-t",required=True,
                        help= "Test ID")
    parser.add_argument('--keysecret', "-k",required=True,
                        help= "Base64 Key:Secret")
    parser.add_argument('--sleepTime', "-s",required=False,
                        help= "Sleep Time for checking status (default each 30s)")
     
    args = parser.parse_args()
    
    keySecret = args.keysecret
    testId = args.testid
    if args.sleepTime:
        sleepTime = args.sleepTime
    
    print("")
    print("BlazeMeter test trigger script...")
    print("---")
    print("Key/Secret: "+keySecret)
    print("Test ID: "+testId)
    print("Sleep Time: "+sleepTime)
    print("---")
    print ("Script started")

    if keySecret == "":
        print ("Key/Secret are mandatory")
        return(-1)
    elif testId == "":
        print ("Test ID is mandatory")
        return(-2)
    elif int(sleepTime) <=0:
        print ("Invalid sleepTime")
        return(-3)
    else:
        print ("Triggering the start of the test...")
        #start the test
        response = requests.post(f"https://a.blazemeter.com/api/v4/tests/{testId}/start?delayedStart=false",
        headers={
            "Authorization": "Basic " + keySecret
        })
        data = response.json()
        print(data)
        try:
            masterId = data['result']['id']
            print("Take a look online at: https://a.blazemeter.com/app/#/masters/"+str(masterId))
        except:
            print ("Error trying to execute the test")
            return(-4)
        else:
            
            #check the status for the execution
            tries = 1000 #loops this amount of time or finishes when the execution reaches the ENDED status
            i = 0
            while i < tries:
                i += 1
                response = requests.get(f"https://a.blazemeter.com/api/v4/masters/{masterId}/status?level=NOTICE",
                headers={
                "Authorization": "Basic " + keySecret
                })
                data = response.json()
                testStatus = data['result']['status']
                print("Status: "+testStatus+". "+sleepTime+"s for the next status check.")
                print("")
                if testStatus == "TERMINATING":
                    print("Test is finishing")
                if testStatus == "ENDED":
                    print("Test is finished. let's check the results.")
                    print("Take a look online at: https://a.blazemeter.com/app/#/masters/"+str(masterId))
                    i=tries+1
                else:
                    print("")
                time.sleep(int(sleepTime))
                #get containerName from the execution info
                sessionId = data['result']['sessions'][0]['id']
                containerName = sessionId+"-0-0-c"

    print ("Script finished")
    return(0)

if __name__ == '__main__':
    sys.exit(main())

