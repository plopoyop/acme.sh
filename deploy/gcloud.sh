#!/usr/bin/env sh

# Script to deploy certificates google compute engine loadbalancer
# You must have generated a json keyfile for your authentication
#
# The following variables exported from environment will be used.
# If not set then values previously saved in domain.conf file are used.
#
# Only a username is required.  All others are optional.
#
# The following examples are for QNAP NAS running QTS 4.2
# export GCLOUD_KEYFILE=""  # required path of your authentication json file
# export GCLOUD_PROJECT=""  # required google compute engine project name
# export GCLOUD_PROXY=""  # loadbalancer name wich the certificate must be associated to
# export GCLOUD_CERTNAME="" # required certificate name in compute engine interface. will be suffixed with a sequence number (dont finish the name with a number)
# export GCLOUD_DELETE_PREVIOUS="" # should we delete certificate with previous sequence number
#
########  Public functions #####################

#domain keyfile certfile cafile fullchain
gcloud_deploy() {
  _cdomain="$1"
  _ckey="$2"
  _ccert="$3"
  _cca="$4"
  _cfullchain="$5"

  _debug _cdomain "$_cdomain"
  _debug _ckey "$_ckey"
  _debug _ccert "$_ccert"
  _debug _cca "$_cca"
  _debug _cfullchain "$_cfullchain"

  if [ -f "$DOMAIN_CONF" ]; then
    # shellcheck disable=SC1090
    . "$DOMAIN_CONF"
  fi

  #
  if [ -z "$GCLOUD_KEYFILE" ]; then
    if [ -z "$Le_Deploy_gcloud_keyfile" ]; then
      _err "GCLOUD_KEYFILE not defined."
      return 1
    fi
  else
    Le_Deploy_gcloud_keyfile="$GCLOUD_KEYFILE"
    _savedomainconf Le_Deploy_gcloud_keyfile "$Le_Deploy_gcloud_keyfile"
  fi

  #
  if [ -z "$GCLOUD_PROJECT" ]; then
    if [ -z "$Le_Deploy_gcloud_project" ]; then
      _err "GCLOUD_PROJECT not defined."
      return 1
    fi
  else
    Le_Deploy_gcloud_project="$GCLOUD_PROJECT"
    _savedomainconf Le_Deploy_gcloud_project "$Le_Deploy_gcloud_project"
  fi

  if [ -z "$GCLOUD_PROXY" ]; then
    if [ -z "$Le_Deploy_gcloud_proxy" ]; then
      _info "GCLOUD_PROXY not defined certificate won't be associated automaticly."
    fi
  else
    Le_Deploy_gcloud_proxy="$GCLOUD_PROXY"
    _savedomainconf Le_Deploy_gcloud_proxy "$Le_Deploy_gcloud_proxy"
  fi

  if [ -z "$GCLOUD_CERTNAME" ]; then
    if [ -z "$Le_Deploy_gcloud_cert_name" ]; then
        _err "GCLOUD_CERTNAME not defined."
        return 1
    fi
  else
    Le_Deploy_gcloud_cert_name="$GCLOUD_CERTNAME"
    _savedomainconf Le_Deploy_gcloud_cert_name "$Le_Deploy_gcloud_cert_name"
  fi

  if [ -z "$GCLOUD_DELETE_PREVIOUS" ]; then
    if [ -z "$Le_Deploy_gcloud_delete_previous" ]; then
      _info "GCLOUD_DELETE_PREVIOUS not defined, older certificate won't be deleted."
    fi
  else
    Le_Deploy_gcloud_delete_previous="$GCLOUD_DELETE_PREVIOUS"
    _savedomainconf Le_Deploy_gcloud_delete_previous "$Le_Deploy_gcloud_delete_previous"
  fi


  _info "Login to gcloud account"
  gcloud auth activate-service-account --key-file $Le_Deploy_gcloud_keyfile


  _info "Get current certificate"
  #bug in gcloud limit need tail -1
  current_cert=`gcloud compute --project=$Le_Deploy_gcloud_project ssl-certificates list --filter=$Le_Deploy_gcloud_cert_name --sort-by CREATION_TIMESTAMP | grep test-clement | tail -1 | sed 's/ .*//'`
  current_cert_number=`echo $current_cert | sed 's/.*-//'`
  if echo $current_cert_number | egrep -q '^[0-9]+$'; then
      _info "Current cert sequence number : $current_cert_number"
  else
      current_cert_number=0
  fi

  next_cert_number=$((current_cert_number + 1))
  next_cert_name="$Le_Deploy_gcloud_cert_name-$next_cert_number"
  _info "New cert name : $next_cert_name"

  _info "Creating certificate"
  gcloud compute --project=$Le_Deploy_gcloud_project ssl-certificates --quiet create \
  $next_cert_name --certificate $_cfullchain --private-key $_ckey

  ret=$?
  if [ $ret -ne 0 ]; then
        _err "Error while creating certificate - exiting"
        return 1
  fi

  if [ -z "$Le_Deploy_gcloud_proxy" ]; then
      _info "No proxy defined. Certificate created. Associate it manually"
      return 0
  fi

  gcloud compute target-https-proxies --project=$Le_Deploy_gcloud_project  update $Le_Deploy_gcloud_proxy --ssl-certificates $next_cert_name

  ret=$?
  if [ $ret -ne 0 ]; then
        _err "Error while updating proxy - exiting"
        return 1
  fi

  if [ -z "$Le_Deploy_gcloud_delete_previous" ] || [ $Le_Deploy_gcloud_delete_previous = false ]; then
      _info "Deletion disabled"
      return 0
  fi

  gcloud compute --project=$Le_Deploy_gcloud_project ssl-certificates --quiet delete $current_cert

  ret=$?
  if [ $ret -ne 0 ]; then
        _err "Error while deleting certificate"
        return 1
  fi
  _info "Finished"
  return 0

}
