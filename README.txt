This is a privacy-oriented, (somewhat) secured VPS meant to offer a quick solution accessible via NoMachine on MacOS, Linux, or Windows. After running Terraform apply, the IP address of the instance will be provided.

Use NoMachine to connect to the instance.

There's a $4 charge per month at the time this repo is being deployed for the 50GB of solid state storage, a small price to pay for speed.

When you're done with the machine it's recommended to stop it via AWS CLI to save moneys:

aws ec2 stop-instances --instance-ids <INSTANCE_ID>

When you're ready to use your device again:

aws ec2 start-instances --instance-ids <INSTANCE_ID>

And once it's back up and running just fetch your IP to connect via NoMachine:

aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query "Reservations[0].Instances[0].PublicIpAddress" --output text

I'll be locking this device down more in the future, and will also be adding multiple hops...enjoy.

PLEASE BEAR IN MIND THAT LEAVING THIS MACHINE ACTIVE WITH AN OPEN INGRESS IS A VERY BAD IDEA IF IT IS UNPATCHED - THE IDEA IS THAT YOU SPIN THE MACHINE DOWN AFTER A COUPLE HOURS OF USE SO THAT IT GETS A NEW IP - IF YOU HAVE A STATIC IP GREAT, BUT SINCE THE IDEA IS TO BE ANONYMOUS YOU'RE PROBABLY USING A VPN - THE BEST WAY AROUND THIS IS TO SET IT TO YOUR CURRENT IP AND THEN DESTROY THE ENVIRONMENT WHEN YOU'RE DONE ASSUMING YOU DON'T WANT ANY PERSISTENCE...

In the future I will be expanding this TF script into multi-hop infrastructure with hardening and logging.