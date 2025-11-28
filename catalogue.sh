#!/bin/bash
USER_ID=$(id -u)
# giving colours as  per our wish 
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOG_FOLDER="/var/log/Shell"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOG_FOLDER/$SCRIPT_NAME.log"
MONGO_DB="mongodb.daws-86.shop"
SCRIPT_DIR=$PWD
#creating log file by getting log path and script details and storing in variables
mkdir -p $LOG_FOLDER
echo "Script execution started at: $(date)" | tee -a $LOG_FILE

#check whether script is running under root access or not
if [ $USER_ID -ne 0 ]; then
   echo -e " $R ERROR:Please execute the script under root access $N" | tee -a $LOG_FILE
   exit 1 # we are manually forcing to exit from execution if any error occured
fi
#creating function for  validation once package installed 
VALIDATE(){ if [ $1 -ne 0 ]; then
   echo -e "ERROR....$R $2 is FAILURE $N" | tee -a $LOG_FILE
   exit 1
else
   echo -e "$R $2 is SUCCESS $N" | tee -a $LOG_FILE
fi
}

dnf module disable nodejs -y &>>$LOG_FILE
VALIDATE $? "Disabling nodejs"

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "enabling nodejs:20"

dnf install nodejs -y  &>>$LOG_FILE
VALIDATE $? "Installing nodejs"

id roboshop
if [ $? -ne 0 ]; then
useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
VALIDATE $? "Creating system_user"
else
echo -e "System user already exists....$Y Skipping $N"
fi

mkdir -p /app &>>$LOG_FILE
VALIDATE $? "Creating app"

curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading Scripts"

cd /app
rm -rf /app/* &>>$LOG_FILE

unzip /tmp/catalogue.zip &>>$LOG_FILE
VALIDATE $? "unziping catalogue"

npm install &>>$LOG_FILE
VALIDATE $? "Installing all dependencies provided by developers"

chown -R roboshop:roboshop  /app &>>$LOG_FILE
VALIDATE $? "Changing ownership from root to roboshop"

cp $SCRIPT_DIR/catalogue.service  /etc/systemd/system/ 
VALIDATE $? "Coping catalogue service to repos path"

systemctl daemon-reload

systemctl enable catalogue &>>$LOG_FILE
VALIDATE $? "Enabling catalogue"

systemctl start catalogue &>>$LOG_FILE
VALIDATE $? "starting catalogue"

cp $SCRIPT_DIR/mongo.repo /etc/yum.repos.d/
VALIDATE $? "Coping mongo.repo"

dnf install mongodb-mongosh -y &>>$LOG_FILE
VALIDATE $? "Installing Mongodb client"

STATUS=$(mongosh --host $MONGO_DB --eval 'db.getMongo().getDBNames().indexOf("catalogue")') 
if [ $STATUS -lt 0 ]; then
 mongosh --host $MONGO_DB < /root/app/db/master-data.js &>>$LOG_FILE
 VALIDATE $? "Loading data into mongodb"
else
  echo -e "Data already loaded into Mongodb....$Y Skipping $N"
fi

systemctl restart catalogue
VALIDATE $? "restarting catalogue"











