#!/usr/bin/env bash
set -e

bw_cache_items() {
  DOC="Cache Bitwarden multiple items in the socket-credential-cache
Usage:
  bitwarden-cache-items [options] ITEMNAME...

Options:
  --cache-for=SECONDS   Cache item for retrieval without a session [default: 0]
  -p --purpose PURPOSE  Specify why the master password is required.
                        The text will be appended to
                        'Enter your Bitwarden Master Password to ...'
"
# docopt parser below, refresh this parser with `docopt.sh bitwarden-cache-items.sh`
# shellcheck disable=2016,1075,2154
docopt() { parse() { if ${DOCOPT_DOC_CHECK:-true}; then local doc_hash
if doc_hash=$(printf "%s" "$DOC" | (sha256sum 2>/dev/null || shasum -a 256)); then
if [[ ${doc_hash:0:5} != "$digest" ]]; then
stderr "The current usage doc (${doc_hash:0:5}) does not match \
what the parser was generated with (${digest})
Run \`docopt.sh\` to refresh the parser."; _return 70; fi; fi; fi
local root_idx=$1; shift; argv=("$@"); parsed_params=(); parsed_values=()
left=(); testdepth=0; local arg; while [[ ${#argv[@]} -gt 0 ]]; do
if [[ ${argv[0]} = "--" ]]; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break
elif [[ ${argv[0]} = --* ]]; then parse_long
elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then parse_shorts
elif ${DOCOPT_OPTIONS_FIRST:-false}; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break; else
parsed_params+=('a'); parsed_values+=("${argv[0]}"); argv=("${argv[@]:1}"); fi
done; local idx; if ${DOCOPT_ADD_HELP:-true}; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then
stdout "$trimmed_doc"; _return 0; fi; done; fi
if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${longs[$idx]} = "--version" ]]; then stdout "$DOCOPT_PROGRAM_VERSION"
_return 0; fi; done; fi; local i=0; while [[ $i -lt ${#parsed_params[@]} ]]; do
left+=("$i"); ((i++)) || true; done
if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then error; fi; return 0; }
parse_shorts() { local token=${argv[0]}; local value; argv=("${argv[@]:1}")
[[ $token = -* && $token != --* ]] || _return 88; local remaining=${token#-}
while [[ -n $remaining ]]; do local short="-${remaining:0:1}"
remaining="${remaining:1}"; local i=0; local similar=(); local match=false
for o in "${shorts[@]}"; do if [[ $o = "$short" ]]; then similar+=("$short")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ ${#similar[@]} -gt 1 ]]; then
error "${short} is specified ambiguously ${#similar[@]} times"
elif [[ ${#similar[@]} -lt 1 ]]; then match=${#shorts[@]}; value=true
shorts+=("$short"); longs+=(''); argcounts+=(0); else value=false
if [[ ${argcounts[$match]} -ne 0 ]]; then if [[ $remaining = '' ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${short} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
else value=$remaining; remaining=''; fi; fi; if [[ $value = false ]]; then
value=true; fi; fi; parsed_params+=("$match"); parsed_values+=("$value"); done
}; parse_long() { local token=${argv[0]}; local long=${token%%=*}
local value=${token#*=}; local argcount; argv=("${argv[@]:1}")
[[ $token = --* ]] || _return 88; if [[ $token = *=* ]]; then eq='='; else eq=''
value=false; fi; local i=0; local similar=(); local match=false
for o in "${longs[@]}"; do if [[ $o = "$long" ]]; then similar+=("$long")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ $match = false ]]; then i=0; for o in "${longs[@]}"; do
if [[ $o = $long* ]]; then similar+=("$long"); [[ $match = false ]] && match=$i
fi; ((i++)) || true; done; fi; if [[ ${#similar[@]} -gt 1 ]]; then
error "${long} is not a unique prefix: ${similar[*]}?"
elif [[ ${#similar[@]} -lt 1 ]]; then
[[ $eq = '=' ]] && argcount=1 || argcount=0; match=${#shorts[@]}
[[ $argcount -eq 0 ]] && value=true; shorts+=(''); longs+=("$long")
argcounts+=("$argcount"); else if [[ ${argcounts[$match]} -eq 0 ]]; then
if [[ $value != false ]]; then
error "${longs[$match]} must not have an argument"; fi
elif [[ $value = false ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${long} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
fi; if [[ $value = false ]]; then value=true; fi; fi; parsed_params+=("$match")
parsed_values+=("$value"); }; required() { local initial_left=("${left[@]}")
local node_idx; ((testdepth++)) || true; for node_idx in "$@"; do
if ! "node_$node_idx"; then left=("${initial_left[@]}"); ((testdepth--)) || true
return 1; fi; done; if [[ $((--testdepth)) -eq 0 ]]; then
left=("${initial_left[@]}"); for node_idx in "$@"; do "node_$node_idx"; done; fi
return 0; }; optional() { local node_idx; for node_idx in "$@"; do
"node_$node_idx"; done; return 0; }; oneormore() { local i=0
local prev=${#left[@]}; while "node_$1"; do ((i++)) || true
[[ $prev -eq ${#left[@]} ]] && break; prev=${#left[@]}; done
if [[ $i -ge 1 ]]; then return 0; fi; return 1; }; value() { local i
for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; local value
value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then
eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done
return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() {
printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() {
[[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:396}
usage=${DOC:62:52}; digest=8c983; shorts=('' -p); longs=(--cache-for --purpose)
argcounts=(1 1); node_0(){ value __cache_for 0; }; node_1(){ value __purpose 1
}; node_2(){ value ITEMNAME a true; }; node_3(){ optional 0 1; }; node_4(){
optional 3; }; node_5(){ oneormore 2; }; node_6(){ required 4 5; }; node_7(){
required 6; }; cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:62:52}" >&2; exit 1; }'; unset var___cache_for \
var___purpose var_ITEMNAME; parse 7 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__cache_for" "${prefix}__purpose" "${prefix}ITEMNAME"
eval "${prefix}"'__cache_for=${var___cache_for:-0}'
eval "${prefix}"'__purpose=${var___purpose:-}'
if declare -p var_ITEMNAME >/dev/null 2>&1; then
eval "${prefix}"'ITEMNAME=("${var_ITEMNAME[@]}")'; else
eval "${prefix}"'ITEMNAME=()'; fi; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__cache_for" "${prefix}__purpose" "${prefix}ITEMNAME"; done
}
# docopt parser above, complete command for generating this parser is `docopt.sh bitwarden-cache-items.sh`
  checkdeps socket-credential-cache bitwarden-fields

  eval "$(docopt "$@")"

  local name
  local cache_name
  for name in "${ITEMNAME[@]}"; do
    cache_name="Bitwarden $name"
    # shellcheck disable=2154
    if ! socket-credential-cache get "$cache_name" >/dev/null 2>&1; then
      if [[ -z $BW_SESSION ]]; then
        export BW_SESSION
        # shellcheck disable=2154
        BW_SESSION=$(bitwarden-unlock --purpose="$__purpose")
        trap "bw lock >/dev/null" EXIT
      fi
      bitwarden-fields --cache-for="$__cache_for" "$name" >/dev/null
    fi
  done
}

checkdeps() {
  local deps=("$@")
  local dep
  local out
  local ret=0
  for dep in "${deps[@]}"; do
    if ! out=$(type "$dep" 2>&1); then
      printf -- "Dependency %s not found:\n%s\n" "$dep" "$out"
      ret=1
    fi
  done
  return $ret
}

bw_cache_items "$@"
