######################################################################################### 
# This script is used to update the Azure SQL Database table named "AzureSubscriptions" # 
# with the latest list of subscription IDs & Names.                                     #
#########################################################################################

# Define the trigger for the pipeline
trigger:
  batch: true
  branches:
    include:
    - notrigger 

# Define the schedule for the pipeline to run
schedules:
- cron: "0 0 1 * *"
  displayName: Monthly
  branches:
    include:
    - notrigger

# Define the virtual machine image to use for the pipeline
pool:
  vmImage: 'windows-latest'

# Define the variables to use in the pipeline
variables:
  serviceConnection: 'ZAR Platform Automation'

# Define the stages for the pipeline
stages:
  - stage: UpdateSubs
    displayName: Update Sub ID & Names 
    jobs: 
      - job: updateSqlDB
        displayName: Update SQL DB
        steps: 
          - task: AzurePowerShell@5
            inputs: 
              azureSubscription: $(serviceConnection)
              ScriptType: "InlineScript"
              Inline: | 
                # Get all subscriptions
                $subs = Get-AzSubscription | Select-Object -Property Name, Id

                # Export the results to Azure SQL Database table named "AzureSubscriptions"

                # Define the server name, database name, username and password for the Azure SQL Database
                $serverName = "dbs-san-azureenablement.database.windows.net"
                $databaseName = "SDB-SBG-AzurePlatformVisibility"
                $username = "azureadmin"
                $password = (Get-AzKeyVaultSecret -VaultName "KV-PlatformAutomation" -Name "AdminPassword").SecretValue

                # Convert the username and password to plain text
                //$updatedUsername = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($username))
                $updatedPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($password)) 

                # Create a connection to the Azure SQL Database 
                $connectionString = "Server=$serverName;Database=$databaseName;Integrated Security=False;User ID=$username;Password=$UpdatedPassword;Connect Timeout=30;Encrypt=False;TrustServerCertificate=False;ApplicationIntent=ReadWrite;MultiSubnetFailover=False"
                $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
                $connection.Open() # Open the connection
                
                # Create a command to insert the results into the table
                
                $command = New-Object System.Data.SqlClient.SqlCommand
                
                $command.Connection = $connection

                # Clear the database before adding an updated list of the subscription IDs & Names 

                $command.CommandText = "DELETE FROM AzureSubscriptions"
                $command.ExecuteNonQuery()

                # Insert into the database 
                $command.CommandText = "INSERT INTO AzureSubscriptions (SubscriptionName, SubscriptionID) VALUES (@SubscriptionName, @SubscriptionID)"
                
                $command.Parameters.Add("@SubscriptionName", [System.Data.SqlDbType]::VarChar, 50)
                
                $command.Parameters.Add("@SubscriptionID", [System.Data.SqlDbType]::VarChar, 50)
                
                # Loop through the results and insert them into the table
                
                foreach ($sub in $subs) {
                
                    $command.Parameters["@SubscriptionName"].Value = $sub.Name
                
                    $command.Parameters["@SubscriptionID"].Value = $sub.Id
                
                    $command.ExecuteNonQuery() # Execute the SQL command
                }
                
                # Close the connection
                
                $connection.Close()
              azurePowerShellVersion: "LatestVersion"
