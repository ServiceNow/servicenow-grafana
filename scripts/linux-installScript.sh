#!/bin/bash
# Linux install script for ServiceNow-Optimiz Plugin
# Created By: Braden Still-Routley (Optimiz)

# 1. What package manager are you using? (a)pt or (y)um
# 2. Would you like to install Grafana on this system? (y)es or (n)o
# If yes then 2.1. Would you like to install Nginx as a reverse proxy? (y)es or (n)o
parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

installGrafana="blank"
while [ "$installGrafana" != "n" ] && [ "$installGrafana" != "y" ] && [ "$installGrafana" != "N" ] && [ "$installGrafana" != "Y" ]
do
    if [ "$installGrafana" != "blank" ]
    then
        echo $installGrafana was not a valid option
    fi
    echo Would you like to install Grafana on this system? \(y\)es or \(n\)o
    read installGrafana
done

if [ "$installGrafana" == "y" ] || [ "$installGrafana" == "Y" ]
then
    manager="blank"
    while [ "$manager" != "a" ] && [ "$manager" != "y" ] && [ "$manager" != "A" ] && [ "$manager" != "Y" ]
    do
        if [ "$manager" != "blank" ]
        then
            echo $manager was not a valid option
        fi
        echo What package manager are you using? \(a\)pt or \(y\)um
        read manager
    done

    installNginx="blank"
    while [ "$installNginx" != "n" ] && [ "$installNginx" != "y" ] && [ "$installNginx" != "N" ] && [ "$installNginx" != "Y" ]
    do
        if [ "$installNginx" != "blank" ]
        then
            echo $installNginx was not a valid option
        fi
        echo Would you like to install Nginx as a reverse proxy? \(y\)es or \(n\)o
        read installNginx
    done
else
    echo Only installing Plugin and Dashboards
fi

echo $manager $installGrafana $installNginx $parent_path

if [ "$manager" == "y" ] || [ "$manager" == "Y" ]
then
    sudo yum update -y
    sudo yum install unzip -y
else
    sudo apt-get -y update
    sudo apt-get -y install unzip
fi

curl -o sn-grafana.zip https://codeload.github.com/optimizca/servicenow-grafana/zip/refs/heads/main
unzip sn-grafana.zip
rm -f sn-grafana.zip

if [ "$installGrafana" == "y" ] || [ "$installGrafana" == "Y" ]
then
    if [ "$manager" == "y" ] || [ "$manager" == "Y" ]
    then
        cp servicenow-grafana-main/scripts/grafana.repo /etc/yum.repos.d/grafana.repo
        sudo yum install grafana -y

        sudo systemctl daemon-reload
        sudo systemctl start grafana-server
        sudo systemctl enable grafana-server

        fullname=$(/opt/aws/bin/ec2-metadata -p)
        domain=${fullname:17}
        sed -i "s/^;domain = localhost.*/domain = ${domain}/" /etc/grafana/grafana.ini
        if [ "$installNginx" == "y" ] || [ "$installNginx" == "Y" ]
        then
            amazon-linux-extras install nginx1 -y
            mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
			cp servicenow-grafana-main/scripts/nginx.conf /etc/nginx/nginx.conf
            systemctl enable nginx
            systemctl restart nginx
            sed -i "s/;root_url = .*/root_url = %\(protocol\)s:\/\/%\(domain\)s\//" /etc/grafana/grafana.ini
        fi
    else
        sudo apt-get -y install apt-transport-https software-properties-common wget
        wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
        echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
        sudo apt-get -y update
        sudo apt-get -y install grafana

        sudo systemctl daemon-reload
        sudo systemctl start grafana-server
        sudo systemctl enable grafana-server
        domain=$(hostname --fqdn)
        echo "domain = ${domain}" | sudo tee -a "/etc/grafana/grafana.ini" > /dev/null
        if [ "$installNginx" == "y" ] || [ "$installNginx" == "Y" ]
        then
            sudo apt-get -y install nginx
            mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
			cp servicenow-grafana-main/scripts/nginx.conf /etc/nginx/nginx.conf
            systemctl enable nginx
            systemctl restart nginx
            sed -i "s/;root_url = .*/root_url = %\(protocol\)s:\/\/%\(domain\)s\//" /etc/grafana/grafana.ini
        fi
    fi
fi

sudo rm -rf /var/lib/grafana/plugins/servicenow-optimiz-plugin
sudo cp -r servicenow-grafana-main/dist /var/lib/grafana/plugins/servicenow-optimiz-plugin

sudo rm -rf /var/lib/grafana/plugins/novatec-sdg-panel
curl -o novatec-sdg.zip https://codeload.github.com/R2DToo/novatec-service-dependency-graph-panel/zip/refs/heads/master
unzip novatec-sdg.zip
rm -f novatec-sdg.zip
sudo mv novatec-service-dependency-graph-panel-master/dist /var/lib/grafana/plugins/novatec-sdg-panel
rm -rf novatec-service-dependency-graph-panel-master

sudo rm -f /etc/grafana/provisioning/dashboards/linux-SNOWdashboards.yaml
sudo cp servicenow-grafana-main/dashboards/linux-SNOWdashboards.yaml /etc/grafana/provisioning/dashboards/linux-SNOWdashboards.yaml

sudo rm -rf /var/lib/grafana/dashboards/SNOWdashboards
sudo mkdir -p /var/lib/grafana/dashboards/SNOWdashboards
sudo cp -r servicenow-grafana-main/dashboards /var/lib/grafana/dashboards/SNOWdashboards/

rm -rf servicenow-grafana-main