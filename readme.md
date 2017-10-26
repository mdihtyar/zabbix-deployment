### About
Repository contain docker-compose project for running zabbix server on your own server
Also there is Dockerfile that contains zabbix agent

Zabbix server 3.4
MariaDB 10.3

###
Requirements

1. docker-ce (1.13.0+)
1. docker-compose

### Run Zabbix server

```shell
$ docker-compose up -d
```

Frontend url is: http://localhost if you launch project on your local machine.

Default user for zabbix is: admin / zabbix

To run project with specific options, please see `.env.example` file.
To apply non default option, copy `.env.example` file to `.env` and
edit necessary values there.

#### Testing a deployment of environment

Project contains Vagrantfile that can be used for testing running the project.

If VM does not exist yes, launch next command:
```
$ vagrant up
```

After succesfully completed provision scenario it is possible to get access to
Zabbix UI by url: http://192.168.33.102 - internal IP address of VM.

Repeat provision scenario
```
$ vagrant provision
```