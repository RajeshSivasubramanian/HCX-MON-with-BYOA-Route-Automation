<# PowerShell Script to Add /32 static host route(s) on AVS Connected Tier1GW based on MON enabled VM /32 static routes added by HCX on Multiple AVS Isolated Tier1GWs. 
This is an infinite loop but can be stopped by pressing Ctrl+C Key.
#>

# Function to get all static routes from the user supplied T1GW
function GetT1GWStaticRoutes {
  param (
    [string]$Tier1RouterID,
    [string]$NSXTMgrURL,
    [string]$NSXUsername,
    [String]$NSXPassword
  )
  $nsxsecurepassword = ConvertTo-SecureString "$NSXPassword" -AsPlainText -Force
  $nsxcred = New-Object System.Management.Automation.PSCredential ("$NSXUsername", $nsxsecurepassword)
  $url = "https://$NSXTMgrURL/policy/api/v1/infra/tier-1s/$Tier1RouterID/static-routes"
  try 
  {
    Invoke-RestMethod -Uri $url -Authentication Basic -Credential $nsxcred -Method Get -ContentType "application/json" -SkipCertificateCheck
  }
  catch 
  {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
  }
}

# Function to push/patch static routes to the connected T1GW
function PostT1GWStaticRoutes {
  param (
    [string]$Tier1RouterID,
    [string]$NSXTMgrURL,
    [string]$StaticRoute,
    [string]$NextHop,
    [string]$RouteID,
    [string]$RouteName,
    [string]$NSXUsername,
    [string]$NSXPassword
  )
  $nsxsecurepassword = ConvertTo-SecureString "$NSXPassword" -AsPlainText -Force
  $nsxcred = New-Object System.Management.Automation.PSCredential ("$NSXUsername", $nsxsecurepassword)
  $JSONPayload = @"
    {
        "resource_type":"Infra",
        "children":[
          {
            "resource_type":"ChildTier1",
            "marked_for_delete":"false",
            "Tier1":{
              "resource_type":"Tier1",
              "id":"$Tier1RouterID",
              "children":[
                {
                  "resource_type":"ChildStaticRoutes",
                  "marked_for_delete":false,
                  "StaticRoutes":{
                    "network":"$StaticRoute",
                    "next_hops":[
                      {
                        "ip_address":"$NextHop",
                        "admin_distance":1
                      }
                    ],
                    "resource_type":"StaticRoutes",
                    "id":"$RouteID",
                    "display_name":"$RouteName",
                    "children":[],
                    "marked_for_delete":false
                  }
                }
              ]
            }
          }
        ]
    }
"@
  # REST API Patach request to AVS based NSX-T to deploy the static host route
    try
    {
    Invoke-RestMethod -Uri "https://$NSXTMgrURL/policy/api/v1/infra.json" -Authentication Basic -Credential $nsxcred -Method Patch -Body $JSONPayload -ContentType "application/json" -SkipCertificateCheck
    Write-Host ("{0} : The static route {1} is added to the connected T1GW Static Route Table" -f $(Get-Date), $StaticRoute) -ForegroundColor Red
    } 
    catch 
    {
      Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
      Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    }  
}

# <<<<<<<<<<<<<<   Main code starts here  >>>>>>>>>>>>>

Write-host("PowerShell Script to Add /32 static host route(s) on AVS Connected Tier1GW based on MON enabled VM /32 static routes added by HCX on Multiple AVS Isolated Tier1GWs. 
This is an infinite loop but can be stopped by pressing Ctrl+C Key:") -ForegroundColor DarkMagenta

# Defining AVS NSX-T URL, user name and password and other User inputs to probe static routes and push the same onto connected T1GW - comment/uncomment as needed

#$nsxurl = [string] (Read-Host -Prompt "Enter your AVS SDDC NSX-T Manager IP Address:")
#$nsxusername = [string] (Read-Host -Prompt "Enter your AVS SDDC NSX-T Manager User Name:")
#$nsxpassword = [string] (Read-Host -Prompt "Enter your AVS SDDC NSX-T Manager Password:")
#$IsolatedT1GWList = [string] (Read-Host -Prompt "Enter your list of AVS SDDC NSX-T Isolated Tier1 Gateway Names separated by a comma [',']:")
#$T1GW = [string] (Read-Host -Prompt "Enter your AVS SDDC NSX-T Tier1 Gateway Name:")
#$T1GW_NVA_NHOP = [string] (Read-Host -Prompt "Enter your AVS SDDC NSX-T Tier1 Gateway to NVA Next-Hop IP Address(without netmask):")
#$ProbeInterval = [Int] (Read-Host -Prompt "Enter the Isolated T1GW Static Route Probe interval in seconds:")
#$FilePath_To_Log = [string] (Read-Host -Prompt "Enter the Full File Path to log AVS SDDC NSX-T Tier1 Gateway Route additions:")
#$IsolatedT1GWs = $IsolatedT1GWList.Split(",")

do 
{
  Write-Host ("This is an infinite loop probing MON /32 routes at 10 seconds interval and you can press CTRL+C at any time to exit from the loop:") -ForegroundColor DarkRed
 
  ForEach ($IsolatedT1GW in $IsolatedT1GWs)  # Iterate over multiple Isolated T1GWs based on user input 
  {
    Write-Host ("{0}: Probing the Isolated T1GW {1} Static Route Table:" -f $(Get-Date), $IsolatedT1GW) -ForegroundColor DarkYellow
    # Getting the isolated T1GW static route table
    $IsolatedT1GWRouteData = GetT1GWStaticRoutes -Tier1RouterID $IsolatedT1GW -NSXTMgrURL $nsxurl -nsxusername $nsxusername -nsxpassword $nsxpassword
    $IsolatedT1GWRoutes = $IsolatedT1GWRouteData.results
    # Getting the Connected T1GW static route table
    $T1GWRoutesData = GetT1GWStaticRoutes -Tier1RouterID $T1GW -NSXTMgrURL $nsxurl -nsxusername $nsxusername -nsxpassword $nsxpassword
    $T1GWRoutes = $T1GWRoutesData.results
    $TotalT1GWRoutes=0

    if ($T1GWRoutes.Count -eq 0) # This to cover a use case where there are no static routes in Connected T1GW to start with (may be fresh install and before migration)
    {
        Write-Host ("Connected T1GW Route Table is Empty") -ForegroundColor DarkRed
        
        ForEach ($IsolatedT1GWRoute in $IsolatedT1GWRoutes)
        {
           if ($IsolatedT1GWRoute.display_name -like "HCX Policy based MON for Subnet*") # Checking if there are any HCX MON based /32 Routes in Isolated T1GW for VMs that are migrated
            {
                PostT1GWStaticRoutes -Tier1RouterID $T1GW -NSXTMgrURL $nsxurl -StaticRoute $IsolatedT1GWRoute.network -NextHop $T1GW_NVA_NHOP -RouteID ($IsolatedT1GWRoute.network -split '/')[0] -RouteName $IsolatedT1GWRoute.network -nsxusername $nsxusername -nsxpassword $nsxpassword
                "{0} : The static route {1} is not present in the connected T1GW Static Route Table, so adding the same to the route table!" -f $(Get-Date), $IsolatedT1GWRoute.network | Out-File -FilePath "$FilePath_To_Log" -Append
            }
        }
    }
    else 
    {
      ForEach ($IsolatedT1GWRoute in $IsolatedT1GWRoutes)
      {
        if ($IsolatedT1GWRoute.display_name -like "HCX Policy based MON for Subnet*") # Checking if there are any HCX MON based /32 Routes in Isolated T1GW for VMs that are migrated
        {
          ForEach ($T1GWRoute in $T1GWRoutes)
          {
            $TotalT1GWRoutes+=1
            if ($IsolatedT1GWRoute.network -eq $T1GWRoute.network) # Checking if the /32 static MON routes are already present in Connected T1GW Route Table
            {
              Write-Host ("The static route {0} is already present in the connected T1GW Static Route Table, so skipping the same" -f $IsolatedT1GWRoute.network) -ForegroundColor DarkGreen
              $TotalT1GWRoutes=0
              break
            }
            elseif ($TotalT1GWRoutes -eq $T1GWRoutes.Count) #  if the /32 static MON routes are present then add the same to Connected T1GW Route Table
            {
              Write-Host ("{0} : The static route {1} is not present in the connected T1GW Static Route Table, so adding the same to the route table!" -f $(Get-Date), $IsolatedT1GWRoute.network) -ForegroundColor DarkRed
              "{0} : The static route {1} is not present in the connected T1GW Static Route Table, so adding the same to the route table!" -f $(Get-Date), $IsolatedT1GWRoute.network | Out-File -FilePath "$FilePath_To_Log" -Append
              PostT1GWStaticRoutes -Tier1RouterID $T1GW -NSXTMgrURL $nsxurl -StaticRoute $IsolatedT1GWRoute.network -NextHop $T1GW_NVA_NHOP -RouteID ($IsolatedT1GWRoute.network -split '/')[0] -RouteName $IsolatedT1GWRoute.network -nsxusername $nsxusername -nsxpassword $nsxpassword
              $TotalT1GWRoutes=0
            }
          }
        }
      }
    } 
  }
  Start-Sleep -Seconds $ProbeInterval
} while ($true -or ([System.Console]::ReadKey($true)).Key -eq "Ctrl+C") # Run this checks in periodic loop or Run till user presses Ctrl+C Key
