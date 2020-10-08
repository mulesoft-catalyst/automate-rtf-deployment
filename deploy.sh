
#!/usr/bin/env bash
client_id=<client_id_of_connected_app>
client_secret=<client_secret_of_connected_app>
orgId=<org_id>
appName=hello-mule-api
appVersion=1.0.0
jarName=hello-mule
appFolder=$(pwd) 
RTFClusterName=<rtf_cluster_name>
environment=<runtime_environment_name>
cpuReserved=500m
cpuLimit=500m
memReserved=1000Mi
memoryLimit=1000Mi
clustered=false
enforceReplicasAcrossNodes=false
publicUrl=<public_url_for_rtf_application>
runtimeVersion=4.3.0:v1.2.37
lastMileSecurity=false
updateStrategy=rolling
disableAmLogForwarding=false
replicas=1
groupId=<org_id>
artifactId=hello-mule-api
artifactVersion=1.0.0
applicationName=hello-mule-api
isDelete=false

### Retrieve Access token using Connected APP ClientId and ClientSecret
### Pre-requisite - Create a connected app in Anypoint platform access management which has all required permissions

access_token=$(curl -s -X POST \
https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "client_id=$client_id&client_secret=$client_secret&grant_type=client_credentials" | jq -r '.access_token')

echo "Access Token: $access_token"

### Check if the asset already exists in Exchange

exchngAssetResponseCode=$(curl -s -L -X GET "https://anypoint.mulesoft.com/exchange/api/v1/assets/$orgId/$appName?includeSnapshots=true" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $access_token" -o exchngAssetResponse.json -w "%{http_code}")

exchngAssetStatus=$(jq -r '.status' exchngAssetResponse.json)

echo "Exchange Asset Status: $exchngAssetStatus, Response Code: $exchngAssetResponseCode"

### If asset does not exist in Exchange then upload POM file and application jar into exchange with artifactVersion(usually 1.0.0)

if [[ $exchngAssetStatus -eq 404 ]]
then
echo "Asset does not exist in Exchange"

### Pre-requisite - mvn clean package is already executed and jar file is present in current directory

assetUploadStatus=$(curl -s -X PUT \
 -k https://maven.anypoint.mulesoft.com/api/v1/organizations/$orgId/maven/$orgId/$appName/$artifactVersion/$appName-$artifactVersion-mule-application.jar \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/java-archive" \
 -H "X-ANYPNT-ORG-ID: $orgId" \
 --data-binary @/$appFolder/$jarName.jar -o /dev/null -w "%{http_code}") 

echo "Asset upload Status Code: $assetUploadStatus" 

### Create POM.xml file by updating template pom.tpl.xml with actual values

pomXML=$(sed -E "s/{{groupId}}/$groupId/;s/{{artifactId}}/$artifactId/;s/{{version}}/$artifactVersion/;s/{{name}}/$applicationName/;s/{{propAppName}}/$applicationName/" pom.tpl.xml)

echo "Uploading POM"

uploadPOMStatus=$(curl -s -X PUT "https://maven.anypoint.mulesoft.com/api/v1/organizations/$orgId/maven/$orgId/$appName/$artifactVersion/$appName-$artifactVersion.pom" \
-H "Authorization: Bearer $access_token" \
-H "X-ANYPNT-ORG-ID: $orgId" \
-H "Content-Type: application/xml" \
-d "$pomXML" -o /dev/null -w "%{http_code}")

echo "POM upload Status Code: $uploadPOMStatus" 
fi

### If asset already exists in Exchange then retrieve latest artifact version and increase it by 1
### Then  upload POM file and application jar into exchange with updated artifactVersion

if [[ $exchngAssetStatus = 'published' ]]
then

echo "Asset already exists in Exchange"

exchngAssetVersion=$(jq -r '.version' exchngAssetResponse.json)

nextAssetVersion=$(echo $exchngAssetVersion | awk -F. -v OFS=. 'NF==1{print ++$NF}; NF>1{if(length($NF+1)>length($NF))$(NF-1)++; $NF=sprintf("%0*d", length($NF), ($NF+1)%(10^length($NF))); print}')

echo "Next Asset Version: $nextAssetVersion"

artifactVersion=$nextAssetVersion

echo "updated artifact version: $artifactVersion"

### Pre-requisite - mvn clean package is already executed and jar file is present in current directory

assetUploadStatus=$(curl -s -X PUT \
 -k https://maven.anypoint.mulesoft.com/api/v1/organizations/$orgId/maven/$orgId/$appName/$artifactVersion/$appName-$artifactVersion-mule-application.jar \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/java-archive" \
 -H "X-ANYPNT-ORG-ID: $orgId" \
 --data-binary @/"$appFolder"/$jarName.jar -o /dev/null -w "%{http_code}") 

echo "Asset upload Status Code: $assetUploadStatus" 

### Create POM.xml file by updating template pom.tpl.xml with actual values

pomXML=$(sed -E "s/{{groupId}}/$groupId/;s/{{artifactId}}/$artifactId/;s/{{version}}/$artifactVersion/;s/{{name}}/$applicationName/;s/{{propAppName}}/$applicationName/" pom.tpl.xml)

echo "Uploading POM"

uploadPOMStatus=$(curl -s -X PUT "https://maven.anypoint.mulesoft.com/api/v1/organizations/$orgId/maven/$orgId/$appName/$artifactVersion/$appName-$artifactVersion.pom" \
-H "Authorization: Bearer $access_token" \
-H "X-ANYPNT-ORG-ID: $orgId" \
-H "Content-Type: application/xml" \
-d "$pomXML" -o /dev/null -w "%{http_code}")

echo "POM upload Status Code: $uploadPOMStatus" 

fi

### Retrieve all deployment agent details

agentsInfo=$(curl -s -X GET \
 https://anypoint.mulesoft.com/workercloud/api/organizations/$orgId/agents \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" | jq)

agentId=$(echo "$agentsInfo" | jq -c --arg RTFClusterName "$RTFClusterName" '.[] | select(.agentInfo.name | contains($RTFClusterName))' | jq -r '.id')

### Note - As an alternate You can read targetId from a property file once cluster is created and this step can be skipped

echo "RTF agentId: $agentId"

targetId=$agentId

### Retrieve environment id. In this case for Dev

envDetails=$(curl -s -X GET \
 https://anypoint.mulesoft.com/accounts/api/organizations/$orgId/environments \
 -H "Authorization: Bearer $access_token" | jq)

devenvId=$(echo "$envDetails" | jq -c --arg environment "$environment" '.data[] | select(.name | contains($environment))' | jq -r '.id')

echo "Dev Env Id: $devenvId"

### Note - You can read devenvId from a property file once cluster is created and this step can be skipped

deploymentsResponse=$(curl -s -X GET \
 https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$devenvId/deployments \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -o deploymentsResponse.json -w "%{http_code}")

deploymentId=$(jq -c --arg appName "$appName" '.items[] | select(.name | contains($appName))' deploymentsResponse.json | jq -r '.id')

echo "DeploymentId: $deploymentId"

### Create application configuration to be used during deploying a new app or update existing one

appConfig=$(jq --arg appName "${appName}" \
    --arg targetId "${targetId}" \
    --arg cpuReserved "${cpuReserved}" \
    --arg cpuLimit "${cpuLimit}" \
    --arg memReserved "${memReserved}" \
    --arg memoryLimit "${memoryLimit}" \
    --argjson clustered "${clustered}" \
    --argjson enforceReplicasAcrossNodes "${enforceReplicasAcrossNodes}" \
    --arg publicUrl "${publicUrl}" \
    --arg runtimeVersion "${runtimeVersion}" \
    --argjson lastMileSecurity "${lastMileSecurity}" \
    --arg updateStrategy "${updateStrategy}" \
    --argjson disableAmLogForwarding "${disableAmLogForwarding}" \
    --argjson replicas "${replicas}" \
    --arg groupId "${groupId}" \
    --arg artifactId "${artifactId}" \
    --arg artifactVersion "${artifactVersion}" \
    --arg applicationName "${applicationName}" \
    '.name = $appName | .target.targetId = $targetId | .target.deploymentSettings.resources.cpu.reserved = $cpuReserved | .target.deploymentSettings.resources.cpu.limit = $cpuLimit | 
     .target.deploymentSettings.resources.memory.reserved = $memReserved | .target.deploymentSettings.resources.memory.limit = $memoryLimit |
     .target.deploymentSettings.clustered = $clustered | .target.deploymentSettings.enforceDeployingReplicasAcrossNodes = $enforceReplicasAcrossNodes | .target.deploymentSettings.http.inbound.publicUrl = $publicUrl |
     .target.deploymentSettings.runtimeVersion = $runtimeVersion | .target.deploymentSettings.lastMileSecurity = $lastMileSecurity | .target.deploymentSettings.updateStrategy = $updateStrategy |
     .target.deploymentSettings.disableAmLogForwarding = $disableAmLogForwarding | 
     .target.replicas = $replicas | .application.ref.groupId = $groupId | .application.ref.artifactId = $artifactId | .application.ref.version = $artifactVersion | 
     .application.configuration."mule.agent.application.properties.service".applicationName = $applicationName' appConfig.tpl.json)

### In case there is no deployment id retrieved for the application it should be deployed as new application

if [ -z "$deploymentId" ]
then

echo "App does not exist in RTF"

deploymentStatus=$(curl -s -X POST \
 https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$devenvId/deployments \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" \
 -d "$appConfig" -o deployResponse.json -w "%{http_code}")

else

### If application is already deployed it is updated with app configuration

echo "App exists in RTF"

deploymentStatus=$(curl -s -X PATCH \
 https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$devenvId/deployments/$deploymentId \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" \
 -d "$appConfig" -o deployResponse.json -w "%{http_code}")

fi

echo "RTF deployment status: $deploymentStatus"

deploymentId=$(jq -r '.id' deployResponse.json)

echo "deploymentId: $deploymentId"

### Since it would time for app to deploy the process is put to sleep
### Note - This can also be replaced by a loop process which can check status every x seconds

sleep 180

### Check deployment status. In case it is not successful go through error workflow like delete application from exchange, send notification etc.

deployStatusResponse=$(curl -s -X GET \
 https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$devenvId/deployments/$deploymentId \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -o deployStatusResponse.json)

deployStatus=$(jq -r '.status' deployStatusResponse.json)
appStatus=$(jq -r '.application.status' deployStatusResponse.json)

echo "deployStatus: $deployStatus,appStatus: $appStatus"

if [ $deployStatus = 'APPLIED' ] && [ $appStatus = 'RUNNING' ] 
then
echo "Asset successfully deployed to $environment"
fi

### Optional - Delete application and artifact jars from RTF cluster and exchange
if [[ $isDelete ]]
then
echo "Asset does not need to be deleted"
fi

if $isDelete 
then
echo "Asset needs to be deleted"

deleteAppStatus=$(curl -s -X DELETE \
 https://anypoint.mulesoft.com/hybrid/api/v2/organizations/$orgId/environments/$devenvId/deployments/$deploymentId \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" -w "%{http_code}")

echo "App Deletion Status: $deleteAppStatus"

exchngAssetDeleteStatus=$(curl -s -X DELETE \
 https://anypoint.mulesoft.com/exchange/api/v1/organizations/$orgId/assets/$orgId/$artifactId \
 -H "Authorization: Bearer $access_token" \
 -H "Content-Type: application/json" \
 -H "X-Delete-Type: hard-delete" -w "%{http_code}")

echo "Exchange Asset Deletion Status: $exchngAssetDeleteStatus" 

fi


