#!zsh
# fancy list-colors
# Originally nicoulaj at
# http://www.reddit.com/r/zsh/comments/msps0/color_partial_tab_completions_in_zsh/c367xqo

# Thank you very much Julien Nicoulaud!

# Adapted by: Takeshi Banse <takebi@laafc.net>, public domain
# I want to teach the $LS_COLORS as much as possible.

# Code

local ZERO="$0"

list-colors-init () {
  setopt localoptions no_ksharrays no_kshzerosubscript errreturn extendedglob
  local install="$1"
  local dircolorsfile="$2"; [[ -e "$dircolorsfile" ]]
  local colordefsfile="$3"; [[ -e "$colordefsfile" ]]
  eval "$(dircolors -b "$colordefsfile")"
  local d="$LS_COLORS"
  local -A colordefs;
  eval \
${(j:;:)${${(s.:.)d}//(#b)(*)=(*)/colordefs[${match[1]#\*.}]=\"$match[2]\"}}

  eval "$(dircolors -b $dircolorsfile)"
  local s="$LS_COLORS"
  local -A tmp2
  local -a match mbegin mend
  eval \
${(j:;:)${${(s.:.)s}//(#b)(*)=(*)/tmp2[\"${match[2]}\"]+=$match[1]$'\0'}}
  list-colors-init-dimmifycall () {
    local fn="$1"
    local -a match mbegin mend
    case "${(Q)2}" in
      (01\;(#b)(3?))
        $fn $match[1]
      ;;
      ((#b)(*)(38\;5\;)([^\;]#)(*))
        local s="${colordefs[a${match[3]}]-}"
        if [[ -n "${s}" ]]; then
          $fn ${match[1]}$s${match[4]}
          return
        fi
      ;|
      (*)
        $fn ${colordefs[i*]}
      ;;
    esac
  }
  list-colors-init-cursorifycall () {
    local fn="$1"
    local -a match mbegin mend
    case "${(Q)2}" in
      ((#b)(*)(38\;5\;)([^\;]#)(*))
        local s="${colordefs[c${match[3]}]-}"
        if [[ -n "${s}" ]]; then
          $fn "$s"
          return
        fi
      ;|
      (*)
        $fn ${colordefs[c*]}
      ;;
    esac
  }
  list-colors-init-aux () {
    local fn="$1"
    local keycolor="$2"
    local -a vals; : ${(A)vals::=${(M)${(0)tmp2[${keycolor}][1,-2]}:#\**}}
    if [[ -n "$vals" ]] && ((${#vals}!=0)); then
      $fn \
'(^*-#directories)=(#bi)('$'\0'')(?)*~^('${(j.|.)${vals}}')='${(Q)keycolor}'='${(Q)$(list-colors-init-dimmifycall $fn ${keycolor})}'='$(list-colors-init-cursorifycall $fn ${keycolor})
    fi
  }

  local -a tmp
  local -A colordefssub
  : ${(A)tmp::=${(M)${(s.:.)LS_COLORS}}}
  eval \
${(j:;:)${${tmp}//(#b)(*)=(*)/colordefssub[${match[1]#\*.}]=\"$match[2]\"}}
  : ${(A)tmp::=${(k)tmp2/(#m)*/$(list-colors-init-aux echo $MATCH)}}
  tmp+="=(#bi)((#B)("$'\0'")|("$'\0\0'"))=${colordefs[sameish]}"
  local s=; zstyle -s ':completion:*' list-separator s || :
  tmp+="=(#bi)((#B)("$'\0'")|("$'\0\0'"))[[:space:]##]*${s---}*==${colordefs[sameish]}"
  tmp+="(^*-#directories)=(#bi)("$'\0'")(?)*=${colordefssub[no]-}=${colordefs[anormal]}=${colordefs[cnormal]}"
  tmp+="(*-#directories)=(#bi)("$'\0'")(?)*=${colordefssub[di]}=${colordefs[adir]}=${colordefs[cdir]}"
  unfunction list-colors-init-{aux,dimmifycall,cursorifycall}
  $install tmp
}

list-colors () {
  local listcolorsaux="${1-}"
  local -a match mbegin mend
  local prefix=;
  : ${(A)reply::=${(s.:.)LS_COLORS}}
  [[ -z "$PREFIX" ]] || {
    prefix="${PREFIX:t}"
    [[ "$PREFIX[-1]" == "/" ]] && prefix="$PREFIX"
    [[ -z "${listcolorsaux}" ]] || () {
      setopt localoptions no_ksharrays no_kshzerosubscript no_shwordsplit
      local -a w; : ${(A)w::=${(A)words}}
      local -i c=0
      while { (($#w != 0)) && \
          [[ $w[1] == (-|builtin|command|exec|nocorrect|noglob) ]] }; do
        shift w; ((c++))
      done
      $listcolorsaux prefix $c -- "$w[@]"
    }
    reply+=(${${LIST_COLORS//$'(\0)'/"(${prefix})"}//$'(\0\0)'/"(${PREFIX})"})
  }
}

list-colors-install () {
  typeset -ga +r LIST_COLORS; : ${(A)LIST_COLORS::=${(PA)1}};
  typeset     -r LIST_COLORS
}

list-colors-aux () {
  local   pp="$1"; shift
  local -i c="$1"; shift
  shift # --
  [[ $@[1] == git ]] && {
    if [[ $@[2] == show ]]; then
      : ${(P)pp::=${PREFIX#*:}}
    elif [[ -z ${(M)@[1,((CURRENT-c))]:#--} ]]; then
      : ${(P)pp::=${PREFIX}}
    fi
  }
}

list-colors-zcompile () {
  local dircolorsfile="$1"
  local initfile="$2/list-colors-init"
  local colorfile="${3-${ZERO:A:h}/data/default}"
  local zcompilep="${4-t}"
  echo "** Dumping and zcompiling for "$dircolorsfile""
  list-colors-init list-colors-install "$dircolorsfile" "$colorfile"
  (($?==0)) || {
    echo $0': failed. Sorry for the inconvenience.'
    echo '(re-runnig after `setopt xtrace'' would help to identify problems)'
    return 128
  }
  setopt localoptions errreturn
  autoload -Uz zrecompile
  zmodload zsh/datetime
  {
    print "#autoload"
    print "# NOTE: Generated from below files. Please DO NOT EDIT."
    print "#  - ${(D)dircolorsfile:A}"
    print "#  - ${(D)ZERO:A}"
    print  "LIST_COLORS=("
    print -lr ${(qqqq)LIST_COLORS}
    print  ")"
    functions list-colors list-colors-aux
  } >| "$initfile"
  [[ "$zcompilep" == t ]] || return
  () { setopt localoptions unset; zrecompile -p -z "$1" } "$initfile"
  command touch \
    --date="$(strftime "%F %T" $((EPOCHSECONDS + 2)))" "$initfile".zwc
  echo "** All done."
  echo "** Please update your .zshrc like this:"
  command cat <<EOT
-- >8 --
fpath+=$initfile:h
autoload -Uz list-colors-init; list-colors-init
zstyle -e ':completion:*:default' list-colors list-colors list-colors-aux
-- 8< --
EOT
}
