# HCX MON with BYOA (like FW NVA) - Route Automation

# Introduction
Customers can bring in their own NVA appliance like FW NVA to AVS NSX-T to perform custom firewall segmentation. They want to leverage these FW NVAs to perform E-W inter-zone traffic filtering for the VMs that are part of different extended network segments whilst they want to enable HCX MON for the extended segments and selective VMs that needs optimized local routing. The purpose of this script is to Add /32 static host route(s) on AVS NSX-T "Connected Tier1-GW" based on MON enabled VM /32 static routes added by HCX on Multiple AVS NSX-T "Isolated Tier1-GWs".

# Architecture
This is a AVS NSX-T FW NVA test lab topology used to validate this script.

![image](https://user-images.githubusercontent.com/101758347/224368420-fea23614-8ea9-49d8-bbfc-1501941099d1.png)

