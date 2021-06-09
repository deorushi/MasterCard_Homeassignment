# MasterCard_Homeassignment

Design Webserver in private subnet, Which are accessible from Application Load Balancer's DNS address

This architecture includes below aws services:
1.	VPC
    It includes:
    Four Subnets - Two public and two privite
    Two Roting tables - Public and Pivate
    Public Routing table is associated with Internet Gateway 
    Private Routing table is associated with NAT Gateway
    
2.	Security Groups
    Two security groups- one for instance and another for load balancer

3.	Target Group
    A target group tells a load balancer where to direct traffic to : EC2 instances
    
    
4.	Load balancer
  	Load Balancing that allows a developer to configure and route incoming end-user traffic to applications based
    
5.	Launch Configuration
    Launch Configuration specify information for the instances such as the ID of the Amazon Machine Image (AMI), the instance type, a key pair, one or more security groups
    
6.	Auto-scaling
    It monitors your halth of webserver and if any instance found unhealthly it will spin new instances.
    
     
