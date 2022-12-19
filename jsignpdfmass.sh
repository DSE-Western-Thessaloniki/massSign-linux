#!/bin/bash

DIRNAME=$(dirname "$(readlink -e "$0")")
DIR=$(cd "$DIRNAME" || exit 112; pwd)

[ "$OSTYPE" = "cygwin" ] && DIR="$( cygpath -m "$DIR" )"

JAVA=java
if [ -n "$JAVA_HOME" ]; then
  JAVA="$JAVA_HOME/bin/java"
fi

JAVA_VERSION=$("$JAVA" -cp "$DIR/JSignPdf.jar" net.sf.jsignpdf.JavaVersion)
if [ "$JAVA_VERSION" -gt "8" ]; then
  JAVA_OPTS="$JAVA_OPTS --add-exports jdk.crypto.cryptoki/sun.security.pkcs11=ALL-UNNAMED --add-exports jdk.crypto.cryptoki/sun.security.pkcs11.wrapper=ALL-UNNAMED --add-exports java.base/sun.security.action=ALL-UNNAMED --add-exports java.base/sun.security.rsa=ALL-UNNAMED --add-opens java.base/sun.security.util=ALL-UNNAMED"
fi

# Προσθήκη συγκεκριμένων επιλογών για το JSignPDF
LANG=el_GR.utf8

echo -n "PIN: "
read -rs JSIGNPWD
echo ""

if [[ "$JSIGNPWD" == "" ]]; then
    echo "Δώθηκε κενό pin. Γίνεται τερματισμός..."
    exit 1
fi

# Κάνε έλεγχο του pin πριν εκτελέσεις την εργασία. Σε περίπτωση αποτυχίας σταμάτησε
# ώστε να μην εξαντληθούν οι δοκιμές pin στο token
"$JAVA" $JAVA_OPTS "-Djsignpdf.home=$DIR" -jar "$DIR/JSignPdf.jar" -kst JSIGNPKCS11 -ksp "$JSIGNPWD" -kp "$JSIGNPWD" -lk
if [[ $? -gt 0 ]]; then
    echo "Παρουσιάστηκε σφάλμα. Πατήστε Enter για να συνεχίσετε..."
    read
    exit $?
fi

FILES=()
for x in "$@"; do
  if [[ -d "$x" ]]; then
    "$JAVA" $JAVA_OPTS "-Djsignpdf.home=$DIR" -jar "$DIR/JSignPdf.jar" -lp -kst JSIGNPKCS11 -ksp "$JSIGNPWD" -kp "$JSIGNPWD" -d "$x" "$x/*.pdf"
    if [[ $? -gt 0 ]]; then
      echo "Παρουσιάστηκε σφάλμα. Πατήστε Enter για να συνεχίσετε..."
      read
      exit $?
    fi
  else
    FILES+=( "$x" )
  fi
  shift
done

# Αν δεν δόθηκαν αρχεία για υπογραφή κάνε τερματισμό
if [[ ${#FILES[@]} -eq 0 ]]; then
  exit 0;
fi

"$JAVA" $JAVA_OPTS "-Djsignpdf.home=$DIR" -jar "$DIR/JSignPdf.jar" -lp -kst JSIGNPKCS11 -ksp "$JSIGNPWD" -kp "$JSIGNPWD" "${FILES[@]}"
if [[ $? -gt 0 ]]; then
    echo "Παρουσιάστηκε σφάλμα. Πατήστε Enter για να συνεχίσετε..."
    read
fi
