#!/bin/bash

##########################################################################
# >> DEFAULT VARS
#
# add them here. 
# Example: DEFAULT_VARS["KEY"]="VALUE"
##########################################################################
declare -A DEFAULT_VARS
DEFAULT_VARS["ENABLE_CLAMAV"]="${ENABLE_CLAMAV:="0"}"
DEFAULT_VARS["ENABLE_SPAMASSASSIN"]="${ENABLE_SPAMASSASSIN:="0"}"
DEFAULT_VARS["ENABLE_POP3"]="${ENABLE_POP3:="0"}"
DEFAULT_VARS["ENABLE_FAIL2BAN"]="${ENABLE_FAIL2BAN:="0"}"
DEFAULT_VARS["ENABLE_MANAGESIEVE"]="${ENABLE_MANAGESIEVE:="0"}"
DEFAULT_VARS["ENABLE_FETCHMAIL"]="${ENABLE_FETCHMAIL:="0"}"
DEFAULT_VARS["ENABLE_LDAP"]="${ENABLE_LDAP:="0"}"
DEFAULT_VARS["ENABLE_SASLAUTHD"]="${ENABLE_SASLAUTHD:="0"}"
DEFAULT_VARS["SMTP_ONLY"]="${SMTP_ONLY:="0"}"
DEFAULT_VARS["VIRUSMAILS_DELETE_DELAY"]="${VIRUSMAILS_DELETE_DELAY:="7"}"
DEFAULT_VARS["DMS_DEBUG"]="${DMS_DEBUG:="0"}"
##########################################################################
# << DEFAULT VARS
##########################################################################


##########################################################################
# >> REGISTER FUNCTIONS
#
# add your new functions/methods here. 
#
# NOTE: position matters when registering a function in stacks. First in First out
# 		Execution Logic: 
# 			> check functions
# 			> setup functions
# 			> fix functions
# 			> misc functions
# 			> start-daemons
#
# Example: 
# if [ CONDITION IS MET ]; then
#   _register_{setup,fix,check,start}_{functions,daemons} "$FUNCNAME"
# fi
#
# Implement them in the section-group: {check,setup,fix,start}
##########################################################################
function register_functions() {
	notify 'taskgrp' 'Initializing setup'
	notify 'task' 'Registering check,setup,fix,misc and start-daemons functions'

	################### >> check funcs

	_register_check_function "_check_environment_variables"
	_register_check_function "_check_hostname"

	################### << check funcs

	################### >> setup funcs

	_register_setup_function "_setup_default_vars"

	if [ "$ENABLE_ELK_FORWARDER" = 1 ]; then
		_register_setup_function "_setup_elk_forwarder"
	fi

	if [ "$SMTP_ONLY" != 1 ]; then
		_register_setup_function "_setup_dovecot"
		_register_setup_function "_setup_dovecot_local_user"
	fi

	if [ "$ENABLE_LDAP" = 1 ];then
		_register_setup_function "_setup_ldap"
	fi

	if [ "$ENABLE_SASLAUTHD" = 1 ];then
		_register_setup_function "_setup_saslauthd"
		_register_setup_function "_setup_postfix_sasl"
	fi

	_register_setup_function "_setup_dkim"
	_register_setup_function "_setup_ssl"
	_register_setup_function "_setup_docker_permit"

	_register_setup_function "_setup_mailname"

	_register_setup_function "_setup_postfix_override_configuration"
	_register_setup_function "_setup_postfix_sasl_password"
	_register_setup_function "_setup_security_stack"
	_register_setup_function "_setup_postfix_aliases"
	_register_setup_function "_setup_postfix_vhost"

	if [ ! -z "$AWS_SES_HOST" -a ! -z "$AWS_SES_USERPASS" ]; then
		_register_setup_function "_setup_postfix_relay_amazon_ses"
	fi

	################### << setup funcs

	################### >> fix funcs

	_register_fix_function "_fix_var_mail_permissions"

	################### << fix funcs

	################### >> misc funcs

	_register_misc_function "_misc_save_states"
	
	################### << misc funcs

	################### >> daemon funcs

	_register_start_daemon "_start_daemons_cron"
	_register_start_daemon "_start_daemons_rsyslog"

	if [ "$ENABLE_ELK_FORWARDER" = 1 ]; then
		_register_start_daemon "_start_daemons_filebeat"
	fi

	if [ "$SMTP_ONLY" != 1 ]; then
		_register_start_daemon "_start_daemons_dovecot"
	fi

	# needs to be started before saslauthd
	_register_start_daemon "_start_daemons_opendkim"
	_register_start_daemon "_start_daemons_opendmarc"
	_register_start_daemon "_start_daemons_postfix"

	if [ "$ENABLE_SASLAUTHD" = 1 ];then
		_register_start_daemon "_start_daemons_saslauthd"
	fi

	# care needs to run after postfix
	if [ "$ENABLE_FAIL2BAN" = 1 ]; then
		_register_start_daemon "_start_daemons_fail2ban"
	fi

	if [ "$ENABLE_FETCHMAIL" = 1 ]; then
		_register_start_daemon "_start_daemons_fetchmail"
	fi

	if [ "$ENABLE_CLAMAV" = 1 ]; then
		_register_start_daemon "_start_daemons_clamav"
	fi

  _register_start_daemon "_start_daemons_amavis"
	################### << daemon funcs
}
##########################################################################
# << REGISTER FUNCTIONS
##########################################################################



# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# >>


##########################################################################
# >> CONSTANTS
##########################################################################
declare -a FUNCS_SETUP
declare -a FUNCS_FIX
declare -a FUNCS_CHECK
declare -a FUNCS_MISC
declare -a DAEMONS_START
declare -A HELPERS_EXEC_STATE
##########################################################################
# << CONSTANTS
##########################################################################


##########################################################################
# >> protected register_functions
##########################################################################
function _register_start_daemon() {
	DAEMONS_START+=($1)
	notify 'inf' "$1() registered"
}

function _register_setup_function() {
	FUNCS_SETUP+=($1)
	notify 'inf' "$1() registered"
}

function _register_fix_function() {
	FUNCS_FIX+=($1)
	notify 'inf' "$1() registered"
}

function _register_check_function() {
	FUNCS_CHECK+=($1)
	notify 'inf' "$1() registered"
}

function _register_misc_function() {
	FUNCS_MISC+=($1)
	notify 'inf' "$1() registered"
}
##########################################################################
# << protected register_functions
##########################################################################


function notify () {
	c_red="\e[0;31m"
	c_green="\e[0;32m"
	c_brown="\e[0;33m"
	c_blue="\e[0;34m"
	c_bold="\033[1m"
	c_reset="\e[0m"

	notification_type=$1
	notification_msg=$2
	notification_format=$3
	msg=""

	case "${notification_type}" in
		'taskgrp')
			msg="${c_bold}${notification_msg}${c_reset}"
			;;
		'task')
			if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
				msg="  ${notification_msg}${c_reset}"
			fi
			;;
		'inf')
			if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
				msg="${c_green}  * ${notification_msg}${c_reset}"
			fi
			;;
		'started')
			msg="${c_green} ${notification_msg}${c_reset}"
			;;
		'warn')
			msg="${c_brown}  * ${notification_msg}${c_reset}"
			;;
		'err')
			msg="${c_red}  * ${notification_msg}${c_reset}"
			;;
		'fatal')
			msg="${c_red}Error: ${notification_msg}${c_reset}"
			;;
		*)
			msg=""
			;;
	esac

	case "${notification_format}" in
		'n')
			options="-ne"
	  	;;
		*)
  		options="-e"
			;;
	esac

	[[ ! -z "${msg}" ]] && echo $options "${msg}"
}

function defunc() {
	notify 'fatal' "Please fix your configuration. Exiting..." 
	exit 1
}

function display_startup_daemon() {
  $1 &>/dev/null
  res=$?
  if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
	  if [ $res = 0 ]; then
			notify 'started' " [ OK ]"
		else
	  	echo "false"
			notify 'err' " [ FAILED ]"
		fi
  fi
	return $res
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, except you know exactly what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# <<



##########################################################################
# >> Check Stack
#
# Description: Place functions for initial check of container sanity
##########################################################################
function check() {
	notify 'taskgrp' 'Checking configuration'
	for _func in "${FUNCS_CHECK[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _check_hostname() {
	notify "task" "Check that hostname/domainname is provided (no default docker hostname) [$FUNCNAME]"

	if ( ! echo $(hostname) | grep -E '^(\S+[.]\S+)$' > /dev/null ); then
		notify 'err' "Setting hostname/domainname is required"
		return 1
	else 
		notify 'inf' "Hostname has been set to $(hostname)"
		return 0
	fi
}

function _check_environment_variables() {
	notify "task" "Check that there are no conflicts with env variables [$FUNCNAME]"
	return 0
}
##########################################################################
# << Check Stack
##########################################################################


##########################################################################
# >> Setup Stack
#
# Description: Place functions for functional configurations here
##########################################################################
function setup() {
	notify 'taskgrp' 'Configuring mail server'
	for _func in "${FUNCS_SETUP[@]}";do
		$_func
	done
}

function _setup_default_vars() {
	notify 'task' "Setting up default variables [$FUNCNAME]"

	for var in ${!DEFAULT_VARS[@]}; do
		echo "export $var=${DEFAULT_VARS[$var]}" >> /root/.bashrc
		[ $? != 0 ] && notify 'err' "Unable to set $var=${DEFAULT_VARS[$var]}" && return 1
		notify 'inf' "Set $var=${DEFAULT_VARS[$var]}"
	done
}

function _setup_mailname() {
	notify 'task' 'Setting up Mailname'

	notify 'inf' "Creating /etc/mailname"
	echo $(hostname -d) > /etc/mailname
}

function _setup_dovecot() {
	notify 'task' 'Setting up Dovecot'

	cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
	# Disable pop3 (it will be eventually enabled later in the script, if requested)
	mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disab
	mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disab
	sed -i -e 's/#ssl = yes/ssl = yes/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#port = 993/port = 993/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#port = 995/port = 995/g' /etc/dovecot/conf.d/10-master.conf
	sed -i -e 's/#ssl = yes/ssl = required/g' /etc/dovecot/conf.d/10-ssl.conf

	# Enable Managesieve service by setting the symlink
	# to the configuration file Dovecot will actually find
	if [ "$ENABLE_MANAGESIEVE" = 1 ]; then
		notify 'inf' "Sieve management enabled"
		mv /etc/dovecot/protocols.d/managesieved.protocol.disab /etc/dovecot/protocols.d/managesieved.protocol
	fi
}

function _setup_dovecot_local_user() {
	notify 'task' 'Setting up Dovecot Local User'
	echo -n > /etc/postfix/vmailbox
	echo -n > /etc/dovecot/userdb
	if [ -f /tmp/docker-mailserver/postfix-accounts.cf -a "$ENABLE_LDAP" != 1 ]; then
		notify 'inf' "Checking file line endings"
		sed -i 's/\r//g' /tmp/docker-mailserver/postfix-accounts.cf
		notify 'inf' "Regenerating postfix user list"
		echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox

		# Checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
		sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf

		chown dovecot:dovecot /etc/dovecot/userdb
		chmod 640 /etc/dovecot/userdb

		sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
		sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

		# Creating users
		# 'pass' is encrypted
		while IFS=$'|' read login pass
		do
			# Setting variables for better readability
			user=$(echo ${login} | cut -d @ -f1)
			domain=$(echo ${login} | cut -d @ -f2)
			# Let's go!
			notify 'inf' "user '${user}' for domain '${domain}' with password '********'"
			echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
			# User database for dovecot has the following format:
			# user:password:uid:gid:(gecos):home:(shell):extra_fields
			# Example :
			# ${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::userdb_mail=maildir:/var/mail/${domain}/${user}
			echo "${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::" >> /etc/dovecot/userdb
			mkdir -p /var/mail/${domain}
			if [ ! -d "/var/mail/${domain}/${user}" ]; then
				maildirmake.dovecot "/var/mail/${domain}/${user}"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Sent"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Trash"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Drafts"
				echo -e "INBOX\nSent\nTrash\nDrafts" >> "/var/mail/${domain}/${user}/subscriptions"
				touch "/var/mail/${domain}/${user}/.Sent/maildirfolder"
			fi
			# Copy user provided sieve file, if present
			test -e /tmp/docker-mailserver/${login}.dovecot.sieve && cp /tmp/docker-mailserver/${login}.dovecot.sieve /var/mail/${domain}/${user}/.dovecot.sieve
			echo ${domain} >> /tmp/vhost.tmp
		done < /tmp/docker-mailserver/postfix-accounts.cf
	else
		notify 'warn' "'config/docker-mailserver/postfix-accounts.cf' is not provided. No mail account created."
	fi
}

function _setup_ldap() {
	notify 'task' 'Setting up Ldap'
	for i in 'users' 'groups' 'aliases'; do
		sed -i -e 's|^server_host.*|server_host = '${LDAP_SERVER_HOST:="mail.domain.com"}'|g' \
			-e 's|^search_base.*|search_base = '${LDAP_SEARCH_BASE:="ou=people,dc=domain,dc=com"}'|g' \
			-e 's|^bind_dn.*|bind_dn = '${LDAP_BIND_DN:="cn=admin,dc=domain,dc=com"}'|g' \
			-e 's|^bind_pw.*|bind_pw = '${LDAP_BIND_PW:="admin"}'|g' \
			/etc/postfix/ldap-${i}.cf
	done

  notify 'inf' "Configuring dovecot LDAP authentification"
	sed -i -e 's|^hosts.*|hosts = '${LDAP_SERVER_HOST:="mail.domain.com"}'|g' \
		-e 's|^base.*|base = '${LDAP_SEARCH_BASE:="ou=people,dc=domain,dc=com"}'|g' \
		-e 's|^dn\s*=.*|dn = '${LDAP_BIND_DN:="cn=admin,dc=domain,dc=com"}'|g' \
		-e 's|^dnpass\s*=.*|dnpass = '${LDAP_BIND_PW:="admin"}'|g' \
		/etc/dovecot/dovecot-ldap.conf.ext

	# Add  domainname to vhost.
	echo $(hostname -d) >> /tmp/vhost.tmp

	notify 'inf' "Enabling dovecot LDAP authentification"
	sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
	sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

	notify 'inf' "Configuring LDAP"
	[ -f /etc/postfix/ldap-users.cf ] && \
		postconf -e "virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf" || \
		notify 'inf' "==> Warning: /etc/postfix/ldap-user.cf not found"

	[ -f /etc/postfix/ldap-aliases.cf -a -f /etc/postfix/ldap-groups.cf ] && \
		postconf -e "virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf, ldap:/etc/postfix/ldap-groups.cf" || \
		notify 'inf' "==> Warning: /etc/postfix/ldap-aliases.cf or /etc/postfix/ldap-groups.cf not found"

	return 0
}

function _setup_postfix_sasl() {
	[ ! -f /etc/postfix/sasl/smtpd.conf ] && cat > /etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: plain login
EOF
	return 0
}

function _setup_saslauthd() {
	notify 'task' "Setting up Saslauthd"

	notify 'inf' "Configuring Cyrus SASL"
	# checking env vars and setting defaults
	[ -z $SASLAUTHD_MECHANISMS ] && SASLAUTHD_MECHANISMS=pam
	[ "$SASLAUTHD_MECHANISMS" = ldap -a -z $SASLAUTHD_LDAP_SEARCH_BASE ] && SASLAUTHD_MECHANISMS=pam
	[ -z $SASLAUTHD_LDAP_SERVER ] && SASLAUTHD_LDAP_SERVER=localhost
	[ -z $SASLAUTHD_LDAP_FILTER ] && SASLAUTHD_LDAP_FILTER='(&(uniqueIdentifier=%u)(mailEnabled=TRUE))'
	([ -z $SASLAUTHD_LDAP_SSL ] || [ $SASLAUTHD_LDAP_SSL == 0 ]) && SASLAUTHD_LDAP_PROTO='ldap://' || SASLAUTHD_LDAP_PROTO='ldaps://'

	if [ ! -f /etc/saslauthd.conf ]; then
		notify 'inf' "Creating /etc/saslauthd.conf"
		cat > /etc/saslauthd.conf << EOF
ldap_servers: ${SASLAUTHD_LDAP_PROTO}${SASLAUTHD_LDAP_SERVER}

ldap_auth_method: bind
ldap_bind_dn: ${SASLAUTHD_LDAP_BIND_DN}
ldap_bind_pw: ${SASLAUTHD_LDAP_PASSWORD}

ldap_search_base: ${SASLAUTHD_LDAP_SEARCH_BASE}
ldap_filter: ${SASLAUTHD_LDAP_FILTER}

ldap_referrals: yes
log_level: 10
EOF
	fi

		 sed -i \
		 -e "/^[^#].*smtpd_sasl_type.*/s/^/#/g" \
		 -e "/^[^#].*smtpd_sasl_path.*/s/^/#/g" \
		 etc/postfix/master.cf

	sed -i \
		-e "s|^START=.*|START=yes|g" \
		-e "s|^MECHANISMS=.*|MECHANISMS="\"$SASLAUTHD_MECHANISMS\""|g" \
		-e "s|^MECH_OPTIONS=.*|MECH_OPTIONS="\"$SASLAUTHD_MECH_OPTIONS\""|g" \
		/etc/default/saslauthd

	if [ "$SASLAUTHD_MECHANISMS" = rimap ]; then
		sed -i \
			-e 's|^OPTIONS="|OPTIONS="-r |g' \
			/etc/default/saslauthd
	fi

	sed -i \
		-e "/smtpd_sasl_path =.*/d" \
		-e "/smtpd_sasl_type =.*/d" \
		-e "/dovecot_destination_recipient_limit =.*/d" \
		/etc/postfix/main.cf
	gpasswd -a postfix sasl
}

function _setup_postfix_aliases() {
	notify 'task' 'Setting up Postfix Aliases'

	echo -n > /etc/postfix/virtual
	echo -n > /etc/postfix/regexp
	if [ -f /tmp/docker-mailserver/postfix-virtual.cf ]; then
		# Copying virtual file
		cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual
		while read from to
		do
			# Setting variables for better readability
			uname=$(echo ${from} | cut -d @ -f1)
			domain=$(echo ${from} | cut -d @ -f2)
			# if they are equal it means the line looks like: "user1     other@domain.tld"
			test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
		done < /tmp/docker-mailserver/postfix-virtual.cf
	else
		notify 'inf' "Warning 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
	fi
	if [ -f /tmp/docker-mailserver/postfix-regexp.cf ]; then
		# Copying regexp alias file
		notify 'inf' "Adding regexp alias file postfix-regexp.cf"
		cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
		sed -i -e '/^virtual_alias_maps/{
		s/ regexp:.*//
		s/$/ regexp:\/etc\/postfix\/regexp/
		}' /etc/postfix/main.cf
	fi
}

function _setup_dkim() {
	notify 'task' 'Setting up DKIM'

	mkdir -p /etc/opendkim && touch /etc/opendkim/SigningTable

	# Check if keys are already available
	if [ -e "/tmp/docker-mailserver/opendkim/KeyTable" ]; then
		cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/
		notify 'inf' "DKIM keys added for: `ls -C /etc/opendkim/keys/`"
		notify 'inf' "Changing permissions on /etc/opendkim"
		chown -R opendkim:opendkim /etc/opendkim/
		# And make sure permissions are right
		chmod -R 0700 /etc/opendkim/keys/
	else
		notify 'warn' "No DKIM key provided. Check the documentation to find how to get your keys."
	fi
}

function _setup_ssl() {
	notify 'task' 'Setting up SSL'

	# SSL Configuration
	case $SSL_TYPE in
		"letsencrypt" )
			# letsencrypt folders and files mounted in /etc/letsencrypt
			if [ -e "/etc/letsencrypt/live/$(hostname)/cert.pem" ] \
			&& [ -e "/etc/letsencrypt/live/$(hostname)/fullchain.pem" ]; then
				KEY=""
				if [ -e "/etc/letsencrypt/live/$(hostname)/privkey.pem" ]; then
					KEY="privkey"
				elif [ -e "/etc/letsencrypt/live/$(hostname)/key.pem" ]; then
					KEY="key"
				fi
				if [ -n "$KEY" ]; then
					notify 'inf' "Adding $(hostname) SSL certificate"

					# Postfix configuration
					sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/letsencrypt/live/'$(hostname)'/fullchain.pem~g' /etc/postfix/main.cf
					sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/letsencrypt/live/'$(hostname)'/'"$KEY"'\.pem~g' /etc/postfix/main.cf

					# Dovecot configuration
					sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/letsencrypt/live/'$(hostname)'/fullchain\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
					sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/letsencrypt/live/'$(hostname)'/'"$KEY"'\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

					notify 'inf' "SSL configured with 'letsencrypt' certificates"
				fi
			fi
		;;
	"custom" )
		# Adding CA signed SSL certificate if provided in 'postfix/ssl' folder
		if [ -e "/tmp/docker-mailserver/ssl/$(hostname)-full.pem" ]; then
			notify 'inf' "Adding $(hostname) SSL certificate"
			mkdir -p /etc/postfix/ssl
			cp "/tmp/docker-mailserver/ssl/$(hostname)-full.pem" /etc/postfix/ssl

			# Postfix configuration
			sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'$(hostname)'-full.pem~g' /etc/postfix/main.cf
			sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'$(hostname)'-full.pem~g' /etc/postfix/main.cf

			# Dovecot configuration
			sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'$(hostname)'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
			sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/postfix/ssl/'$(hostname)'-full\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

			notify 'inf' "SSL configured with 'CA signed/custom' certificates"
		fi
		;;
	"manual" )
		# Lets you manually specify the location of the SSL Certs to use. This gives you some more control over this whole processes (like using kube-lego to generate certs)
		if [ -n "$SSL_CERT_PATH" ] \
		&& [ -n "$SSL_KEY_PATH" ]; then
			notify 'inf' "Configuring certificates using cert $SSL_CERT_PATH and key $SSL_KEY_PATH"
			mkdir -p /etc/postfix/ssl
			cp "$SSL_CERT_PATH" /etc/postfix/ssl/cert
			cp "$SSL_KEY_PATH" /etc/postfix/ssl/key
			chmod 600 /etc/postfix/ssl/cert
			chmod 600 /etc/postfix/ssl/key

			# Postfix configuration
			sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/cert~g' /etc/postfix/main.cf
			sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/key~g' /etc/postfix/main.cf

			# Dovecot configuration
			sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/postfix/ssl/cert~g' /etc/dovecot/conf.d/10-ssl.conf
			sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/postfix/ssl/key~g' /etc/dovecot/conf.d/10-ssl.conf

			notify 'inf' "SSL configured with 'Manual' certificates"
		fi
	;;
"self-signed" )
	# Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
	if [ -e "/tmp/docker-mailserver/ssl/$(hostname)-cert.pem" ] \
	&& [ -e "/tmp/docker-mailserver/ssl/$(hostname)-key.pem"  ] \
	&& [ -e "/tmp/docker-mailserver/ssl/$(hostname)-combined.pem" ] \
	&& [ -e "/tmp/docker-mailserver/ssl/demoCA/cacert.pem" ]; then
		notify 'inf' "Adding $(hostname) SSL certificate"
		mkdir -p /etc/postfix/ssl
		cp "/tmp/docker-mailserver/ssl/$(hostname)-cert.pem" /etc/postfix/ssl
		cp "/tmp/docker-mailserver/ssl/$(hostname)-key.pem" /etc/postfix/ssl
		# Force permission on key file
		chmod 600 /etc/postfix/ssl/$(hostname)-key.pem
		cp "/tmp/docker-mailserver/ssl/$(hostname)-combined.pem" /etc/postfix/ssl
		cp /tmp/docker-mailserver/ssl/demoCA/cacert.pem /etc/postfix/ssl

		# Postfix configuration
		sed -i -r 's~smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem~smtpd_tls_cert_file=/etc/postfix/ssl/'$(hostname)'-cert.pem~g' /etc/postfix/main.cf
		sed -i -r 's~smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key~smtpd_tls_key_file=/etc/postfix/ssl/'$(hostname)'-key.pem~g' /etc/postfix/main.cf
		sed -i -r 's~#smtpd_tls_CAfile=~smtpd_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf
		sed -i -r 's~#smtp_tls_CAfile=~smtp_tls_CAfile=/etc/postfix/ssl/cacert.pem~g' /etc/postfix/main.cf
		ln -s /etc/postfix/ssl/cacert.pem "/etc/ssl/certs/cacert-$(hostname).pem"

		# Dovecot configuration
		sed -i -e 's~ssl_cert = </etc/dovecot/dovecot\.pem~ssl_cert = </etc/postfix/ssl/'$(hostname)'-combined\.pem~g' /etc/dovecot/conf.d/10-ssl.conf
		sed -i -e 's~ssl_key = </etc/dovecot/private/dovecot\.pem~ssl_key = </etc/postfix/ssl/'$(hostname)'-key\.pem~g' /etc/dovecot/conf.d/10-ssl.conf

		notify 'inf' "SSL configured with 'self-signed' certificates"
	fi
	;;
	esac
}

function _setup_postfix_vhost() {
	notify 'task' "Setting up Postfix vhost"

	if [ -f /tmp/vhost.tmp ]; then
		cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
	fi
}

function _setup_docker_permit() {
	notify 'task' 'Setting up PERMIT_DOCKER Option'

	container_ip=$(ip addr show eth0 | grep 'inet ' | sed 's/[^0-9\.\/]*//g' | cut -d '/' -f 1)
	container_network="$(echo $container_ip | cut -d '.' -f1-2).0.0"

	case $PERMIT_DOCKER in
		"host" )
			notify 'inf' "Adding $container_network/16 to my networks"
			postconf -e "$(postconf | grep '^mynetworks =') $container_network/16"
			echo $container_network/16 >> /etc/opendmarc/ignore.hosts
			echo $container_network/16 >> /etc/opendkim/TrustedHosts
			;;

		"network" )
			notify 'inf' "Adding docker network in my networks"
			postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
			echo 172.16.0.0/12 >> /etc/opendmarc/ignore.hosts
			echo 172.16.0.0/12 >> /etc/opendkim/TrustedHosts
			;;

		* )
			notify 'inf' "Adding container ip in my networks"
			postconf -e "$(postconf | grep '^mynetworks =') $container_ip/32"
			echo $container_ip/32 >> /etc/opendmarc/ignore.hosts
			echo $container_ip/32 >> /etc/opendkim/TrustedHosts
			;;
	esac
}

function _setup_postfix_override_configuration() {
	notify 'task' 'Setting up Postfix Override configuration'

	if [ -f /tmp/docker-mailserver/postfix-main.cf ]; then
		while read line; do
			postconf -e "$line"
		done < /tmp/docker-mailserver/postfix-main.cf
		notify 'inf' "Loaded 'config/postfix-main.cf'"
	else
		notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-main.cf' not provided."
	fi
}

function _setup_postfix_sasl_password() {
	notify 'task' 'Setting up Postfix SASL Password'

	# Support general SASL password
	rm -f /etc/postfix/sasl_passwd
	if [ ! -z "$SASL_PASSWD" ]; then
		echo "$SASL_PASSWD" >> /etc/postfix/sasl_passwd
	fi

	# Install SASL passwords
	if [ -f /etc/postfix/sasl_passwd ]; then
		chown root:root /etc/postfix/sasl_passwd
		chmod 0600 /etc/postfix/sasl_passwd
		notify 'inf' "Loaded SASL_PASSWD"
	else
		notify 'inf' "Warning: 'SASL_PASSWD' is not provided. /etc/postfix/sasl_passwd not created."
	fi
}

function _setup_postfix_relay_amazon_ses() {
	notify 'task' 'Setting up Postfix Relay Amazon SES'
	if [ -z "$AWS_SES_PORT" ];then
		AWS_SES_PORT=25
	fi
	notify 'inf' "Setting up outgoing email via AWS SES host $AWS_SES_HOST:$AWS_SES_PORT"
	echo "[$AWS_SES_HOST]:$AWS_SES_PORT $AWS_SES_USERPASS" >> /etc/postfix/sasl_passwd
	postconf -e \
		"relayhost = [$AWS_SES_HOST]:$AWS_SES_PORT" \
		"smtp_sasl_auth_enable = yes" \
		"smtp_sasl_security_options = noanonymous" \
		"smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd" \
		"smtp_use_tls = yes" \
		"smtp_tls_security_level = encrypt" \
		"smtp_tls_note_starttls_offer = yes" \
		"smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
}

function _setup_security_stack() {
	notify 'task' "Setting up Security Stack"

	# recreate auto-generated file
	dms_amavis_file="/etc/amavis/conf.d/51-dms_auto_generated"
  echo "# WARNING: this file is auto-generated." > $dms_amavis_file
	echo "use strict;" >> $dms_amavis_file

	# Spamassassin
	if [ "$ENABLE_SPAMASSASSIN" = 0 ]; then
		notify 'warn' "Spamassassin is disabled. You can enable it with 'ENABLE_SPAMASSASSIN=1'"
		echo "@bypass_spam_checks_maps = (1);" >> $dms_amavis_file
	elif [ "$ENABLE_SPAMASSASSIN" = 1 ]; then
		notify 'inf' "Enabling and configuring spamassassin"
		SA_TAG=${SA_TAG:="2.0"} && sed -i -r 's/^\$sa_tag_level_deflt (.*);/\$sa_tag_level_deflt = '$SA_TAG';/g' /etc/amavis/conf.d/20-debian_defaults
		SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's/^\$sa_tag2_level_deflt (.*);/\$sa_tag2_level_deflt = '$SA_TAG2';/g' /etc/amavis/conf.d/20-debian_defaults
		SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's/^\$sa_kill_level_deflt (.*);/\$sa_kill_level_deflt = '$SA_KILL';/g' /etc/amavis/conf.d/20-debian_defaults
		test -e /tmp/docker-mailserver/spamassassin-rules.cf && cp /tmp/docker-mailserver/spamassassin-rules.cf /etc/spamassassin/
	fi

	# Clamav
	if [ "$ENABLE_CLAMAV" = 0 ]; then
		notify 'warn' "Clamav is disabled. You can enable it with 'ENABLE_CLAMAV=1'"
		echo "@bypass_virus_checks_maps = (1);" >> $dms_amavis_file
	elif [ "$ENABLE_CLAMAV" = 1 ]; then
		notify 'inf' "Enabling clamav"
	fi

	echo "1;  # ensure a defined return" >> $dms_amavis_file


	# Fail2ban
	if [ "$ENABLE_FAIL2BAN" = 1 ]; then
		notify 'inf' "Fail2ban enabled"
		test -e /tmp/docker-mailserver/fail2ban-jail.cf && cp /tmp/docker-mailserver/fail2ban-jail.cf /etc/fail2ban/jail.local
	else
		# Disable logrotate config for fail2ban if not enabled
		rm -f /etc/logrotate.d/fail2ban
	fi

	# Fix cron.daily for spamassassin
	sed -i -e 's~invoke-rc.d spamassassin reload~/etc/init\.d/spamassassin reload~g' /etc/cron.daily/spamassassin

	# Copy user provided configuration files if provided
	if [ -f /tmp/docker-mailserver/amavis.cf ]; then
		cp /tmp/docker-mailserver/amavis.cf /etc/amavis/conf.d/50-user
	fi
}

function _setup_elk_forwarder() {
	notify 'task' 'Setting up Elk forwarder'

	ELK_PORT=${ELK_PORT:="5044"}
	ELK_HOST=${ELK_HOST:="elk"}
	notify 'inf' "Enabling log forwarding to ELK ($ELK_HOST:$ELK_PORT)"
	cat /etc/filebeat/filebeat.yml.tmpl \
		| sed "s@\$ELK_HOST@$ELK_HOST@g" \
		| sed "s@\$ELK_PORT@$ELK_PORT@g" \
		> /etc/filebeat/filebeat.yml
}
##########################################################################
# << Setup Stack
##########################################################################


##########################################################################
# >> Fix Stack
#
# Description: Place functions for temporary workarounds and fixes here
##########################################################################
function fix() {
	notify 'taskgrg' "Post-configuration checks..."
	for _func in "${FUNCS_FIX[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _fix_var_mail_permissions() {
	notify 'task' 'Fixing /var/mail permissions'

	# Fix permissions, but skip this if 3 levels deep the user id is already set
	if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
		notify 'inf' "Fixing /var/mail permissions"
		chown -R 5000:5000 /var/mail
	else
		notify 'inf' "Permissions in /var/mail look OK"
		return 0
	fi
}
##########################################################################
# << Fix Stack
##########################################################################


##########################################################################
# >> Misc Stack
#
# Description: Place functions that do not fit in the sections above here
##########################################################################
function misc() {
	notify 'taskgrp' 'Starting Misc'

	for _func in "${FUNCS_MISC[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _misc_save_states() {
	# Consolidate all state that should be persisted across container restarts into one mounted
	# directory
	statedir=/var/mail-state
	if [ "$ONE_DIR" = 1 -a -d $statedir ]; then
		notify 'inf' "Consolidating all state onto $statedir"
		for d in /var/spool/postfix /var/lib/postfix /var/lib/amavis /var/lib/clamav /var/lib/spamassasin /var/lib/fail2ban; do
			dest=$statedir/`echo $d | sed -e 's/.var.//; s/\//-/g'`
			if [ -d $dest ]; then
				notify 'inf' "  Destination $dest exists, linking $d to it"
				rm -rf $d
				ln -s $dest $d
			elif [ -d $d ]; then
				notify 'inf' "  Moving contents of $d to $dest:" `ls $d`
				mv $d $dest
				ln -s $dest $d
			else
				notify 'inf' "  Linking $d to $dest"
				mkdir -p $dest
				ln -s $dest $d
			fi
		done
	fi
}


##########################################################################
# >> Start Daemons
##########################################################################
function start_daemons() {
	notify 'taskgrp' 'Starting mail server'

	for _func in "${DAEMONS_START[@]}";do
		$_func
		[ $? != 0 ] && defunc
	done
}

function _start_daemons_cron() {
	notify 'task' 'Starting cron' 'n'
	display_startup_daemon "cron"	
}

function _start_daemons_rsyslog() {
	notify 'task' 'Starting rsyslog' 'n'
	display_startup_daemon "/etc/init.d/rsyslog start"	
}

function _start_daemons_saslauthd() {
	notify 'task' 'Starting saslauthd' 'n'
	display_startup_daemon "/etc/init.d/saslauthd start"
}

function _start_daemons_fail2ban() {
	notify 'task' 'Starting fail2ban' 'n'
	touch /var/log/auth.log
	# Delete fail2ban.sock that probably was left here after container restart
  	if [ -e /var/run/fail2ban/fail2ban.sock ]; then
    	  rm /var/run/fail2ban/fail2ban.sock
  	fi
	display_startup_daemon "/etc/init.d/fail2ban start"
}

function _start_daemons_opendkim() {
	notify 'task' 'Starting opendkim' 'n'
	display_startup_daemon "/etc/init.d/opendkim start"
}

function _start_daemons_opendmarc() {
	notify 'task' 'Starting opendmarc' 'n'
	display_startup_daemon "/etc/init.d/opendmarc start"
}

function _start_daemons_postfix() {
	notify 'task' 'Starting postfix' 'n'
	display_startup_daemon "/etc/init.d/postfix start"
}

function _start_daemons_dovecot() {
	# Here we are starting sasl and imap, not pop3 because it's disabled by default
	notify 'task' 'Starting dovecot services' 'n'
	display_startup_daemon "/usr/sbin/dovecot -c /etc/dovecot/dovecot.conf"

	if [ "$ENABLE_POP3" = 1 ]; then
		notify 'task' 'Starting pop3 services' 'n'
		mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
		display_startup_daemon "/usr/sbin/dovecot reload"
	fi

	if [ -f /tmp/docker-mailserver/dovecot.cf ]; then
		cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
		/usr/sbin/dovecot reload
	fi

	# @TODO fix: on integration test 
	# doveadm: Error: userdb lookup: connect(/var/run/dovecot/auth-userdb) failed: No such file or directory
	# doveadm: Fatal: user listing failed

	#if [ "$ENABLE_LDAP" != 1 ]; then
		#echo "Listing users"
		#/usr/sbin/dovecot user '*'
	#fi
}

function _start_daemons_filebeat() {
	notify 'task' 'Starting filebeat' 'n'
	display_startup_daemon "/etc/init.d/filebeat start"
}

function _start_daemons_fetchmail() {
	notify 'task' 'Starting fetchmail' 'n'
	/usr/local/bin/setup-fetchmail
	display_startup_daemon "/etc/init.d/fetchmail start"
}

function _start_daemons_clamav() {
	notify 'task' 'Starting clamav' 'n'
	display_startup_daemon "/etc/init.d/clamav-daemon start"
}

function _start_daemons_amavis() {
	notify 'task' 'Starting amavis' 'n'
	display_startup_daemon "/etc/init.d/amavis start"

	# @TODO fix: on integration test of mail_with_ldap amavis fails because of:
	# Starting amavisd:   The value of variable $myhostname is "ldap", but should have been
	# a fully qualified domain name; perhaps uname(3) did not provide such.
	# You must explicitly assign a FQDN of this host to variable $myhostname
	# in /etc/amavis/conf.d/05-node_id, or fix what uname(3) provides as a host's 
	# network name!

	# > temporary workaround to pass integration test
	return 0
}
##########################################################################
# << Start Daemons
##########################################################################





# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# >>

if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' "# ENV"
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' ""
printenv
fi

notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' "# docker-mailserver"
notify 'taskgrp' "#"
notify 'taskgrp' "#"
notify 'taskgrp' ""

register_functions

check 
setup
fix
misc
start_daemons

notify 'taskgrp' ""
notify 'taskgrp' "#"
notify 'taskgrp' "# $(hostname) is up and running"
notify 'taskgrp' "#"
notify 'taskgrp' ""


tail -fn 0 /var/log/mail/mail.log


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !  CARE --> DON'T CHANGE, unless you exactly know what you are doing
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# <<

exit 0
