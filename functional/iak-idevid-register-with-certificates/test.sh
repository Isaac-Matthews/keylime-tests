#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/share/beakerlib/beakerlib.sh || exit 1

HTTP_SERVER_PORT=8080
AGENT_ID="d432fbb3-d2f1-4a97-9ef7-75bd81c00000"
TPM2_OPENSSL="https://github.com/tpm2-software/tpm2-openssl/releases/download/1.2.0/tpm2-openssl-1.2.0.tar.gz"

rlJournalStart

    rlPhaseStartSetup "Do the keylime setup"
        rlRun 'rlImport "./test-helpers"' || rlDie "cannot import keylime-tests/test-helpers library"
        rlAssertRpm keylime
        # update /etc/keylime.conf
        limeBackupConfig
        # tenant, set to true to verify ek on TPM
        rlRun "limeUpdateConf agent enable_iak_idevid true"
        rlRun "limeUpdateConf registrar tpm_identity iak_idevid"
        # if TPM emulator is present
        if limeTPMEmulated; then
            # start tpm emulator
            rlRun "limeStartTPMEmulator"
            rlRun "limeWaitForTPMEmulator"
            rlRun "limeCondStartAbrmd"
        fi
    rlPhaseEnd

    rlPhaseStartSetup "Install tpm2-openssl to generate csrs with TPM keys"
        rlRun "wget -c ${TPM2_OPENSSL} -O - | tar -xz"
    rlPhaseEnd

    rlPhaseStartSetup "Create CA"
        rlRun "mkdir -p ca/intermediate && cp root.conf ca/ && cp intermediate.conf ca/intermediate/"
        rlRun "cd ca && mkdir private certs newcerts crl && touch index.txt && echo 1000 > serial"
        rlRun "cd intermediate && mkdir private certs newcerts csr crl && touch index.txt && echo 1000 > serial"

        rlRun "cd ../.."
    rlPhaseEnd

    rlPhaseStartSetup "Create keys, csrs, and import certificates"
        rlRun "mkdir ikeys && cd ikeys"
        rlRun "echo -n 494445564944 | xxd -r -p | tpm2_createprimary -C e \
-g sha256 \
-G rsa2048:null:null \
-a 'fixedtpm|fixedparent|sensitivedataorigin|userwithauth|adminwithpolicy|sign' \
-L 'ad6b3a2284fd698a0710bf5cc1b9bdf15e2532e3f601fa4b93a6a8fa8de579ea' \
-u - \
-c idevid.ctx -o idevidtpm2.pem"
        rlRun "echo -n 49414b | xxd -r -p | tpm2_createprimary -C e \
-g sha256 \
-G rsa2048:rsapss-sha256:null \
-a 'fixedtpm|fixedparent|sensitivedataorigin|userwithauth|adminwithpolicy|sign|restricted' \
-L '5437182326e414fca797d5f174615a1641f61255797c3a2b22c21d120b2d1e07' \
-u - \
-c iak.ctx -o iaktpm2.pem"
        rlRun "cat iaktpm2.pem"
        rlRun "cd .."
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "limeStartRegistrar"
        rlRun "limeWaitForRegistrar"
        rlRun "limeStartAgent"
        rlRun "limeWaitForAgentRegistration ${AGENT_ID}"
    rlPhaseEnd

    rlPhaseStartCleanup "Clean up CA, keys and tpm2-openssl"
        rlRun "rm -rf ca"
        rlRun "rm -rf ikeys"
    rlPhaseEnd

    rlPhaseStartCleanup "Do the keylime cleanup"
        rlRun "limeStopAgent"
        rlRun "limeStopRegistrar"
        if limeTPMEmulated; then
            rlRun "limeStopIMAEmulator"
            rlRun "limeStopTPMEmulator"
            rlRun "limeCondStopAbrmd"
        fi
        limeSubmitCommonLogs
        limeClearData
        limeRestoreConfig
    rlPhaseEnd

rlJournalEnd
