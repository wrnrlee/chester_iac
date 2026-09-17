echo "Greetings from The Nether! The server is live. Happy crafting :) \n\n"

INSTANCE_NAME="minecraft-server"
ZONE="us-central1-a"

gcloud compute instances start $INSTANCE_NAME --zone $ZONE

sleep 30s

gcloud compute ssh $INSTANCE_NAME \
    --zone $ZONE \
    --tunnel-through-iap \
    --verbosity=error \
    --quiet \
    --command "sudo su craftsquaw202103; cd ~/scripts; bash start.sh myMcServer"