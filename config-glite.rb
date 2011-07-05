#!/usr/bin/ruby -w

require 'pp'
require 'yaml'
require 'optparse'
require 'net/scp'
require 'net/ssh'
require 'net/ssh/multi'

if ARGV.length != 1
  puts "config-glite YAMLCONFIG"
  exit 1
end

$d = YAML::load(IO::read(ARGV[0]))
puts "\033[1;32m####\033[0m Loaded config file #{ARGV[0]}"

DIR = File.expand_path(File.dirname(__FILE__))

extinction = Proc.new{
  puts "Received extinction request..."
}
%w{INT TERM}.each do |signal|
  Signal.trap( signal ) do
      extinction.call
    exit(1)
  end
end

# FIXME
# Site other clusters
# (listes des clusters d'un site)

def conf_site(vo, bdii, sname, cehost, batch, voms, ui)
  f = File.new("#{DIR}/conf/#{sname}/site-info.def", "w")
  f.puts <<-EOF
## Site-info.def Bdii
SITE_BDII_HOST="#{bdii}"
SITE_NAME=#{sname}
SITE_LOC="#{sname.capitalize}, France"
SITE_WEB="https://www.grid5000.fr/mediawiki/index.php/#{sname.capitalize}:Home"
SITE_LAT="48,7"
SITE_LONG="6,2"
SITE_EMAIL=root@localhost
SITE_SECURITY_EMAIL=sbadia@f#{sname}.#{sname}.grid5000.fr
SITE_SUPPORT_EMAIL=sbadia@f#{sname}.#{sname}.grid5000.fr
SITE_DESC="Grid5000 - gLite"
SITE_OTHER_GRID=""
BDII_REGIONS="CE SITE_BDII BDII WMS"
BDII_CE_URL="ldap://#{cehost}:2170/mds-vo-name=resource,o=grid"
BDII_SITE_BDII_URL="ldap://#{bdii}:2170/mds-vo-name=resource,o=grid"
BDII_WMS_URL="ldap://#{voms}:2170/mds-vo-name=resource,o=grid"
BDII_BDII_URL="ldap://#{bdii}:2170/mds-vo-name=resource,o=grid"

## Site-info.def Batch
BATCH_SERVER="#{batch}"
CE_HOST="#{cehost}"
CE_SMPSIZE=`grep -c processor /proc/cpuinfo`
VOS="#{vo}"
QUEUES="default"
DEFAULT_GROUP_ENABLE="#{vo}"
USERS_CONF=/opt/glite/yaim/etc/conf/users.conf
GROUPS_CONF=/opt/glite/yaim/etc/conf/groups.conf
WN_LIST=/opt/glite/yaim/etc/conf/wn-list.conf
CONFIG_MAUI="yes"

## Site-info.def Batch
BDII_HOST="#{bdii}"
VO_#{vo.upcase}_SW_DIR=/opt/vo_software/#{vo}
VO_#{vo.upcase}_VOMS_CA_DN="/O=Grid/OU=GlobusTest/OU=simpleCA-#{voms}/CN=Globus Simple CA"
VO_#{vo.upcase}_VOMSES="#{vo} #{voms} 15000 /O=Grid/OU=GlobusTest/OU=simpleCA-#{voms}/CN=host/#{voms} #{vo}"
VO_#{vo.upcase}_VOMS_SERVERS="vomss://#{voms}:8443/voms/#{vo}?/#{vo}/"

## Site-info.def Ce
JAVA_LOCATION=/usr/java/default
JOB_MANAGER=pbs
CE_BATCH_SYS=pbs
BATCH_VERSION=torque-2.3.6-2
BATCH_BIN_DIR=/usr/bin
BATCH_LOG_DIR=/var/spool/pbs/
BATCH_SPOOL_DIR=/var/spool/pbs/
CREAM_CE_STATE="Special"
BLPARSER_HOST=#{cehost}
BLAH_JOBID_PREFIX="cream_"
BLPARSER_WITH_UPDATER_NOTIFIER="false"
MYSQL_PASSWORD=koala
APEL_DB_PASSWORD="APELDB_PWD"
APEL_MYSQL_HOST="#{cehost}"
CE_OS_ARCH=x86_64  # uname -i
CE_OS=`lsb_release -i | cut -f2`
CE_OS_RELEASE=`lsb_release -r | cut -f2`
CE_OS_VERSION=`lsb_release -c | cut -f2`
CE_CPU_MODEL=Xeon
CE_CPU_VENDOR=GenuineIntel
CE_CPU_SPEED=2000  # grep MHz /proc/cpuinfo
CE_MINPHYSMEM=16000          # grep MemTotal /proc/meminfo
CE_MINVIRTMEM=4096          # grep SwapTotal /proc/meminfo
CE_OUTBOUNDIP=TRUE
CE_INBOUNDIP=FALSE
CE_RUNTIMEENV="
  GLITE-3_2_0
  R-GMA"
CE_CAPABILITY="none"
CE_OTHERDESCR="Cores=4" #grep -c physical id.*: 0 /proc/cpuinfo
CE_PHYSCPU=2      #grep -c core id.*: 0 /proc/cpuinfo
CE_LOGCPU=1       #grep -c processor /proc/cpuinfo
CE_SI00=1592
CE_SF00=1927
CE_OTHER_DESCR="Cores=1, Benchmark=1.11-HEP-SPEC06"
SE_MOUNT_INFO_LIST="none"
ACCESS_BY_DOMAIN=false
CREAM_DB_USER=creamdb
CREAM_DB_PASSWORD="secretPassword"
BLPARSER_HOST=#{cehost}
BLP_PORT=33333
CREAM_PORT=56565
CEMON_HOST=#{cehost}

## site-info.def voms
MYSQL_PASSWORD="superpass"
VOMS_HOST=#{voms}
VOMS_DB_HOST=#{voms}
VO_#{vo.upcase}_MYSQL_VOMS_PORT=15000
VO_#{vo.upcase}_MYSQL_VOMS_DB_USER=#{vo}u
VO_#{vo.upcase}_MYSQL_VOMS_DB_PASS="superpass"
VO_#{vo.upcase}_MYSQL_VOMS_DB_NAME=#{vo}db
VO_#{vo.upcase}_VOMS_PORT=15000
VO_#{vo.upcase}_VOMS_DB_USER=#{vo}u
VO_#{vo.upcase}_VOMS_DB_PASS="superpass"
VO_#{vo.upcase}_VOMS_DB_NAME=#{vo}db
VOMS_ADMIN_SMTP_HOST=mail.#{sname}.grid5000.fr
VOMS_ADMIN_MAIL=#{ENV['user']}@f#{sname}.#{sname}.grid5000.fr

## site-info.def ui
PX_HOST=#{voms}
RB_HOST=#{voms}
UI_HOST=#{ui}
EOF
  f.close
end # def:: conf_site(bdii, sname, cehost, batch, se, voms)

# <user_id>:<username>:<group_id>:<group_name>:<vo_name>:<special_user_type>:
def conf_users(sname ,vo)
  f = File.new("#{DIR}/conf/#{sname}/users.conf", "w")
  3.times { |a| f.write "#{a + 10410}:sgm#{a +1}:1390,1395:sgm,#{vo}:#{vo}:sgm:\n" }
  3.times { |x| f.write "#{x + 10420}:toto#{x + 1}:1395:#{vo}:#{vo}::\n" }
  f.close
end

# "/<vo>"::::
# "/<vo>/<group>"::::
# "/<vo>/<group>/ROLE=<role>::::
# "/<vo>/<group>/ROLE=<role>:::<special_user_type>:
def conf_groups(sname, vo)
  f = File.new("#{DIR}/conf/#{sname}/groups.conf", "w")
  f.puts <<-EOF
"/#{vo}"::::
"/#{vo}/ROLE=#{vo.upcase}"::::
"/#{vo}/ROLE=VO-Admin":::sgm:
EOF
  f.close
end

def list_wn(sname, wn)
  f = File.new("#{DIR}/conf/#{sname}/wn-list.conf", "w")
    for i in wn
      f.write "#{i}\n"
    end
  f.close
end

def export_nfs()
  f = File.new("#{DIR}/conf/exports", "w")
  f.puts <<-EOF
/var/spool/pbs/server_priv/accounting    *(rw,async,no_root_squash)
/var/spool/pbs/server_logs               *(rw,async,no_root_squash)
EOF
  f.close
end

def queue_config(sname, wn)
  f = File.new("#{DIR}/conf/#{sname}/queue.conf", "w")
  f.puts <<-EOF
#!/bin/sh
qmgr << EOF
set server scheduling = True
set server acl_hosts = *.grid5000.fr
set server managers = root@`hostname -f`
set server operators = root@`hostname -f`
set server default_queue = default
set server scheduler_iteration = 600
set server node_check_rate = 150
set server tcp_timeout = 12
set server poll_jobs = False
set server log_level = 3
set queue default Priority = 100
set queue default max_queuable = 100
set queue default max_running = 100
set queue default resources_max.nodect = #{wn.length - 1}
set server query_other_jobs = True
set server resources_default.cput = 01:00:00
set server resources_default.neednodes = 1
set server resources_default.nodect = #{wn.length - 1}
set server resources_default.nodes = 1
set server default_node = 1#shared
set queue default resources_default.nodes = nodes=1:ppn=1\nEOF
EOF
  f.close
end

$nodes = []

$d['VOs'].each_pair do |name, conf|
  $my_vo = name
  $my_voms = conf['voms']
  $nodes << conf['voms']
end

puts "\033[1;36m###\033[0m Create conf files"
$d['sites'].each_pair do |sname, sconf|
  puts "\033[1;33m==>\033[0m Generate conf::#{sname}"
    Dir::mkdir("#{DIR}/conf/#{sname}/", 0755)
    conf_site($my_vo, sconf['bdii'], sname, sconf['ce'], sconf['batch'], $my_voms, sconf['ui'])
    $nodes << sconf['bdii']
    $nodes << sconf['ce']
    $nodes << sconf['batch']
    $nodes << sconf['ui']
    conf_users(sname ,$my_vo)
    conf_groups(sname, $my_vo)
    export_nfs()
  sconf['clusters'].each_pair do |cname, cconf|
    # FIXME
    # fonction pour liste de noeuds voir fwn
    #list_wn(sname, "#{cconf['nodes']}")
    # FIXME
    # wn.length ne va pas
    queue_config(sname, "#{cconf['nodes']}")
    fwn = File.new("#{DIR}/conf/#{sname}/wn-list.conf", "w")
    cconf['nodes'].each do |n|
      fwn.write "#{n}\n"
      $nodes << n
    end
    fwn.close
  end
end

if ARGV[1]== 1:
  puts "\033[1;36m###\033[0m Update distrib"
  Net::SSH::Multi.start do |session|
    $nodes.each do |node|
      session.use "root@#{node}"
    end
      session.exec('mkdir -p /root/yaim && mkdir -p /opt/glite/yaim/etc && cd /etc/yum.repos.d/ && rm -rf dag.repo* glite-* lcg-* && wget http://public.nancy.grid5000.fr/~sbadia/glite/repo.tgz -q && tar xzf repo.tgz && yum update -q -y')
      session.exec("echo 'mkdir -p /root/yaim && mkdir -p /opt/glite/yaim/etc && cd /etc/yum.repos.d/ && rm -rf dag.repo* glite-* lcg-* && wget http://public.nancy.grid5000.fr/~sbadia/glite/repo.tgz -q && tar xzf repo.tgz && yum update -q -y' >> /root/install.log")
      session.exec("echo 'In Progress'")
      session.exec("cd /root/ && wget http://public.nancy.grid5000.fr/~sbadia/glite/scp-ssh.tgz -q && tar xzf scp-ssh.tgz && chown -R root:root /root/.ssh/")
      session.loop
  end
  $nodes.each do |node|
    Net::SSH.start(node, 'root') do |ssh|
      begin
       Net::SCP.start(node, 'root') do |scp|
         scp.upload!("#{DIR}/conf", "/opt/glite/yaim/etc", :recursive => true)
       end
      rescue
       puts "\033[1;31mErreur\033[0m scp on #{node}"
      end
    end
  end

  puts "\033[1;36m###\033[0m Configuring VOs"
  $d['VOs'].each_pair do |name, conf|
    puts "\033[1;33m==>\033[0m Configuring VO=#{name} on VOMS=#{conf['voms']}"
    Net::SSH.start(conf['voms'], 'root') do |ssh|
      ssh.scp.upload!("#{DIR}/conf/site-info.def","/root/yaim/site-info.def") do |ch, name, sent, total|
        print "\r#{name}: #{(sent.to_f * 100 / total.to_f).to_i}%\n"
      end
      ssh.exec!("yum install mysql-server glite-VOMS_mysql -q -y --nogpgcheck > /dev/null 2>&1")
      ssh.exec!("/etc/init.d/mysqld start > /dev/null 2>&1")
      ssh.exec!("sed -e 's/VOMS_DB_HOST=#{conf['voms']}/VOMS_DB_HOST=localhost/' -i /root/yaim/site-info.def")
      ssh.exec!("chmod 766 /etc/bdii/bdii-slapd.conf && touch /var/log/bdii/bdii-update.log && chmod 766 /var/log/bdii/bdii-update.log")
      ssh.exec!("/usr/bin/mysqladmin -u root password superpass && chmod 766 /var/log/bdii")
      ssh.exec!('chmod -R 600 /root/yaim && /opt/glite/yaim/bin/yaim -c -s /root/yaim/site-info.def -n VOMS -d 1')
      ssh.exec!('echo -e "\ngLite VOMS - (VOMS MySQL)\n" >> /etc/motd')
  end

  puts "## Configuring sites"
  $d['sites'].each_pair do |sname, sconf|
    puts "## Configuring site=#{sname}"
    puts "# BDII on #{sconf['bdii']}"
      Net::SSH.start(sconf['bdii'], 'root') do |ssh|
       ssh.scp.upload!("#{DIR}/conf/#{sname}/site-info.def","/root/yaim/site-info.def") do |ch, name, sent, total|
        print "\r#{name}: #{(sent.to_f * 100 / total.to_f).to_i}%\n"
      end
       ssh.exec!('yum install glite-BDII -q -y')
       ssh.exec!('chmod -R 600 /root/yaim && /opt/glite/yaim/bin/yaim -c -s /root/yaim/site-info.def -n glite-BDII_site -d 1 && echo -e "\ngLite Bdii - (Ldap Berkley database index)\n" >> /etc/motd')

    puts "# Batch on #{sconf['batch']}"
    # FIXME
    puts "# CE on #{sconf['ce']}"
    # FIXME
    puts "# UI on #{sconf['ui']}"
    # FIXME
    puts "## Configuring #{sname}'s clusters"
    sconf['clusters'].each_pair do |cname, cconf|
      puts "# Cluster #{cname} on #{cconf['nodes'].join(' ')}"
      cconf['nodes'].each do |n|
        puts "#{n} ..."
        # FIXME
      end
    end
  end
else
  puts "\033[1;31m==> No install\033[0m"
end
