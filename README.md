# Automate RTF Deployment

## Introduction
This repo allows you automate application deployment into Runtime Fabric from your command line. 
This was created for a CICD tool that allowed ingestion of shell script and curl commands to automate build and deployment. 
It was tested on macOs Catalina. However, it should work on Linux based systems and operating systems that support bash scripts, curl and jq. jq is a lightweight and flexible command-line JSON processor. You can use it to slice and filter and map and transform structured data.

## Prerequisite
- jq - you can download it from [here](https://stedolan.github.io/jq/download/)
- Connected app with appropriate permissions
- deployable archive(jar) file is already created and present in same directory as deploy.sh


## How to use
Clone this repository locally

chmod +x deploy.sh

Change the Variables with your own values in deploy.sh file- 
- client_id=<client_id_of_connected_app>
- client_secret=<client_secret_of_connected_app>
- orgId=<org_id>
- appName=hello-mule-api
- appVersion=1.0.0
- jarName=hello-mule
- appFolder=$(pwd)
- RTFClusterName=<rtf_cluster_name>
- environment=<runtime_environment_name>
- cpuReserved=500m
- cpuLimit=500m
- memReserved=1000Mi
- memoryLimit=1000Mi
- clustered=false
- enforceReplicasAcrossNodes=false
- publicUrl=<public_url_for_rtf_application>
- runtimeVersion=4.3.0:v1.2.37
- lastMileSecurity=false
- updateStrategy=rolling
- disableAmLogForwarding=false
- replicas=1
- groupId=<org_id>
- artifactId=hello-mule-api
- artifactVersion=1.0.0
- applicationName=hello-mule-api
- isDelete=false

Run

./deploy.sh

## Current Limitations
- Anypoint Monitoring sidecar is not part of application configuration template.
- The application jar file is not uploaded successfully to exchange if the current directory has space in its path due to curl command
