#!/usr/bin/bash

#First let's set some important parameters.
#We will need your ""sudo"" password and your required SQL root passwords
echo "First let's set some important parameters..."
echo "We will need your ""sudo"" password and your required SQL root passwords"
read -s -p "What is your sudo password? " passwrd
echo -e "\n"
read -s -p "What is your required SQL root password? " sqlpasswrd
# Go to the home directory
cd $HOME
#Now let's make sure your instance has the most updated packages
echo $passwd | sudo apt update
echo $passwd | sudo apt upgrade -y
#Now let's install a couple of requirements: git, curl and pip
echo "Now let's install a couple of requirements: git, curl and pip"
echo $passwrd | sudo -S apt -qq install nano git curl python3-dev python3.10-dev python3-pip -y
#Next we'll install the python environment manager...
echo "Next we'll install the python environment manager..."
echo $passwrd | sudo -S apt -qq install python3.10-venv -y
#... And mariadb with some extra needed applications.
echo "... And mariadb with some extra needed applications."
echo $passwrd | sudo -S apt -qq install software-properties-common mariadb-server mariadb-client redis-server xvfb libfontconfig wkhtmltopdf -y
#Now we'll go through the required settings of the mysql_secure_installation...
echo "Now we'll go through the required settings of the mysql_secure_installation..."
echo $passwrd | sudo -S mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$sqlpasswrd';"
echo $passwrd | sudo -S mysql -e -p$sqlpasswrd "DELETE FROM mysql.user WHERE User='';"
echo $passwrd | sudo -S mysql -e -p$sqlpasswrd "DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
echo $passwrd | sudo -S mysql -e -p$sqlpasswrd "FLUSH PRIVILEGES;"
echo "...And add some settings to /etc/mysql/my.cnf:"
# Will add the following to /etc/mysql/my.cnf:
#
# [mysqld]
# character-set-client-handshake = FALSE
# character-set-server = utf8mb4
# collation-server = utf8mb4_unicode_ci
#
# [mysql]
# default-character-set = utf8mb4
echo -e "\n\n[mysqld]\ncharacter-set-client-handshake = FALSE\ncharacter-set-server = utf8mb4\ncollation-server = utf8mb4_unicode_ci\n\n[mysql]\ndefault-character-set = utf8mb4"

echo $passwrd | sudo -S sh -c 'echo "\n\n[mysqld]\ncharacter-set-client-handshake = FALSE\ncharacter-set-server = utf8mb4\ncollation-server = utf8mb4_unicode_ci\n\n[mysql]\ndefault-character-set = utf8mb4" >> /etc/mysql/my.cnf'
echo $passwrd | sudo -S service mysql restart
#Install NODE, npm and yarn
echo "Install NODE, npm and yarn"
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install 16
echo $passwrd | sudo -S apt-get -qq install npm -y
echo $passwrd | sudo -S npm install -g yarn
#We need cron
echo "We need cron"
echo $passwrd | sudo -S apt -qq install cron -y
#Install bench
echo "Install bench"
echo $passwrd | sudo -S pip3 install frappe-bench
#Initiate bench in frappe-bench folder, but get a supervisor can't restart bench error...
echo "Initiate bench in frappe-bench folder, but get a supervisor can't restart bench error..."
bench init --frappe-branch version-14 frappe-bench

echo "Would you like to continue with production install? (yes/no)"
read -p "Response: " continue_prod

if [ "$continue_prod" == "yes" ]; then

  # Prompt user for site name
  read -p "Enter the site name (If you wish to install SSL later, please enter a FQDN): " site_name

  # Install expect tool only if needed
  echo $passwrd | sudo -S apt -qq install expect -y
  
  # Prompt user for site name
  read -p "Enter the site name: " site_name

  # Change directory to frappe-bench
  cd frappe-bench && \

  # Get ERPNext app
  bench get-app erpnext --branch version-14 && \

  # Get payments app
  bench get-app payments && \


  bench get-app hrms --branch version-14 && \

  # Create new site
  SECURE_MYSQL=$(expect -c "
  set timeout 10
  bench new-site $site_name --install-app erpnext hrms && \
   expect \"MySQL root password:\"
  send \"$sqlpasswrd\r\"
  expect eof
  ")

  echo "$SECURE_MYSQL"

  # Setup supervisor and nginx config
  yes | sudo bench setup production $USER && \

  # Change ownership of supervisord.conf
  sudo sed -i '6i chown='"$USER"':'"$USER"'' /etc/supervisor/supervisord.conf && \

  # Restart supervisor
  sudo service supervisor restart && \

  # Setup production again to reflect the new site
  yes | sudo bench setup production $USER && \

  # Enable and resume the scheduler for the site
  bench --site $site_name enable-scheduler && \
  bench --site $site_name resume && \

  # Restart bench
  bench restart
else
  echo "Skipping production install..."
fi

