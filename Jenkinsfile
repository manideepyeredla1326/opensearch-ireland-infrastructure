pipeline {
    agent any

    parameters {
        choice(
            name: 'OPERATION',
            choices: ['apply', 'plan', 'validate', 'import', 'backup-state'],
            description: 'Operation to perform'
        )
        string(
            name: 'AWS_REGION',
            defaultValue: 'us-east-1',
            description: 'AWS region for the cluster'
        )
        string(
            name: 'DOMAIN_NAME',
            defaultValue: 'connect-qa',
            description: 'Name of the OpenSearch domain'
        )
        string(
            name: 'AWS_PROFILE',
            defaultValue: 'imiconnect-qa',
            description: 'AWS profile name to use for credentials'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip all input prompts — uses existing tfvars file as-is'
        )
    }

    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        AWS_PROFILE        = "${params.AWS_PROFILE}"
        TF_VAR_file        = "regions/${params.AWS_REGION}/${params.DOMAIN_NAME}.tfvars"
        STATE_REPO_PATH    = "../opensearch-terraform-state"
        GPG_RECIPIENT      = 'myeredla@cisco.com'
        PATH               = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        TF_IN_AUTOMATION   = "true"
    }

    stages {

        // ─────────────────────────────────────────────
        // 1. CHECKOUT
        // ─────────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    if [ ! -d "$STATE_REPO_PATH" ]; then
                        git clone https://github.com/manideepyeredla1326/opensearch-ireland-infrastructure.git $STATE_REPO_PATH
                    else
                        cd $STATE_REPO_PATH && git fetch origin && git reset --hard origin/main
                    fi
                '''
            }
        }

        // ─────────────────────────────────────────────
        // 2. SETUP TOOLS
        // ─────────────────────────────────────────────
        stage('Setup Tools') {
            steps {
                sh '''
                    echo "=== Tool Versions ==="
                    echo "Terraform : $(which terraform) — $(terraform version | head -1)"
                    echo "AWS CLI   : $(which aws) — $(aws --version 2>&1)"
                    echo "jq        : $(which jq) — $(jq --version)"
                '''
            }
        }

        // ─────────────────────────────────────────────
        // 3. CLUSTER DISCOVERY
        //    Detect whether the domain exists in AWS,
        //    display its current config, and ask the
        //    user to choose: existing or new cluster.
        // ─────────────────────────────────────────────
        stage('Cluster Discovery') {
            when {
                expression { params.OPERATION in ['apply', 'plan'] }
            }
            steps {
                script {
                    echo "=== Cluster Discovery: ${params.DOMAIN_NAME} in ${params.AWS_REGION} ==="

                    def awsStatus = sh(
                        script: """
                            aws opensearch describe-domain \
                                --domain-name ${params.DOMAIN_NAME} \
                                --region      ${params.AWS_REGION}  \
                                --profile     ${params.AWS_PROFILE} \
                                --output json > /tmp/aws-domain.json 2>/dev/null \
                            && echo "exists" || echo "not_found"
                        """,
                        returnStdout: true
                    ).trim()

                    env.DOMAIN_IN_AWS = awsStatus

                    if (awsStatus == 'exists') {
                        sh """
                            echo "--- Live AWS Configuration ---"
                            jq -r '.DomainStatus |
                            "  Engine Version  : " + .EngineVersion,
                            "  Instance Type   : " + .ClusterConfig.InstanceType,
                            "  Instance Count  : " + (.ClusterConfig.InstanceCount | tostring),
                            "  Master Enabled  : " + (.ClusterConfig.DedicatedMasterEnabled | tostring),
                            "  Volume Type     : " + .EBSOptions.VolumeType,
                            "  Volume Size (GB): " + (.EBSOptions.VolumeSize | tostring),
                            "  Warm Enabled    : " + (.ClusterConfig.WarmEnabled // false | tostring),
                            "  Processing      : " + (.Processing | tostring),
                            "  Custom Endpoint : " + (.DomainEndpointOptions.CustomEndpoint // "none")
                            ' /tmp/aws-domain.json
                        """
                    } else {
                        echo "Domain '${params.DOMAIN_NAME}' was NOT found in AWS ${params.AWS_REGION}."
                    }

                    if (params.AUTO_APPROVE) {
                        env.CLUSTER_MODE = awsStatus == 'exists' ? 'existing' : 'new'
                        echo "AUTO_APPROVE: cluster mode auto-detected as '${env.CLUSTER_MODE}'"
                    } else {
                        def awsLabel  = awsStatus == 'exists' ? '✅ FOUND in AWS' : '❌ NOT FOUND in AWS'
                        def modeInput = input(
                            id: 'ClusterMode',
                            message: "Domain '${params.DOMAIN_NAME}' — ${awsLabel}\nHow do you want to proceed?",
                            parameters: [
                                choice(
                                    name: 'MODE',
                                    choices: awsStatus == 'exists' ? ['existing', 'new'] : ['new', 'existing'],
                                    description: 'existing = manage live cluster  |  new = provision a brand-new cluster'
                                )
                            ]
                        )
                        env.CLUSTER_MODE = modeInput
                    }

                    echo "Cluster mode set to: ${env.CLUSTER_MODE}"
                }
            }
        }

        // ─────────────────────────────────────────────
        // 4. FETCH & GENERATE TFVARS FROM AWS
        //    Pulls live values and writes a tfvars file
        //    that reflects the actual cluster state.
        //    The user can edit it in the next stage.
        // ─────────────────────────────────────────────
        stage('Fetch & Generate TFVars') {
            when {
                expression { params.OPERATION in ['apply', 'plan'] && env.CLUSTER_MODE == 'existing' }
            }
            steps {
                script {
                    echo "=== Generating TFVars from Live AWS Config ==="

                    sh """#!/bin/bash
                        set -e
                        D=\$(cat /tmp/aws-domain.json)

                        ENGINE_VERSION=\$(echo "\$D" | jq -r '.DomainStatus.EngineVersion')
                        INSTANCE_TYPE=\$(echo "\$D"  | jq -r '.DomainStatus.ClusterConfig.InstanceType')
                        INSTANCE_COUNT=\$(echo "\$D" | jq -r '.DomainStatus.ClusterConfig.InstanceCount')
                        MASTER_ENABLED=\$(echo "\$D" | jq -r '.DomainStatus.ClusterConfig.DedicatedMasterEnabled')
                        MASTER_TYPE=\$(echo "\$D"    | jq -r '.DomainStatus.ClusterConfig.DedicatedMasterType // ""')
                        MASTER_COUNT=\$(echo "\$D"   | jq -r '.DomainStatus.ClusterConfig.DedicatedMasterCount // 0')
                        VOLUME_TYPE=\$(echo "\$D"    | jq -r '.DomainStatus.EBSOptions.VolumeType')
                        VOLUME_SIZE=\$(echo "\$D"    | jq -r '.DomainStatus.EBSOptions.VolumeSize')
                        IOPS=\$(echo "\$D"           | jq -r '.DomainStatus.EBSOptions.Iops // 0')
                        THROUGHPUT=\$(echo "\$D"     | jq -r '.DomainStatus.EBSOptions.Throughput // 0')
                        ENCRYPT=\$(echo "\$D"        | jq -r '.DomainStatus.EncryptionAtRestOptions.Enabled')
                        NODE_ENC=\$(echo "\$D"       | jq -r '.DomainStatus.NodeToNodeEncryptionOptions.Enabled')
                        HTTPS=\$(echo "\$D"          | jq -r '.DomainStatus.DomainEndpointOptions.EnforceHTTPS')
                        ADV_SEC=\$(echo "\$D"        | jq -r '.DomainStatus.AdvancedSecurityOptions.Enabled')
                        CUSTOM_EP=\$(echo "\$D"      | jq -r '.DomainStatus.DomainEndpointOptions.CustomEndpointEnabled // false')
                        CUSTOM_EP_VAL=\$(echo "\$D"  | jq -r '.DomainStatus.DomainEndpointOptions.CustomEndpoint // ""')
                        CERT_ARN=\$(echo "\$D"       | jq -r '.DomainStatus.DomainEndpointOptions.CustomEndpointCertificateArn // ""')
                        VPC_ID=\$(echo "\$D"         | jq -r '.DomainStatus.VPCOptions.VPCId // ""')
                        SUBNET_IDS=\$(echo "\$D"     | jq -r '.DomainStatus.VPCOptions.SubnetIds // [] | @json')
                        SG_ID=\$(echo "\$D"          | jq -r '.DomainStatus.VPCOptions.SecurityGroupIds[0] // ""')
                        KMS_KEY=\$(echo "\$D"        | jq -r '.DomainStatus.EncryptionAtRestOptions.KmsKeyId // ""')
                        WARM_ENABLED=\$(echo "\$D"   | jq -r '.DomainStatus.ClusterConfig.WarmEnabled // false')
                        WARM_TYPE=\$(echo "\$D"      | jq -r '.DomainStatus.ClusterConfig.WarmType // ""')
                        WARM_COUNT=\$(echo "\$D"     | jq -r '.DomainStatus.ClusterConfig.WarmCount // 0')
                        AZS=\$(echo "\$D"            | jq -r '(.DomainStatus.VPCOptions.AvailabilityZones // ["${params.AWS_REGION}a"]) | @json')

                        mkdir -p "\$(dirname "${env.TF_VAR_file}")"

                        cat > "${env.TF_VAR_file}" << TFEOF
domain_name    = "${params.DOMAIN_NAME}"
aws_region     = "${params.AWS_REGION}"
region_name    = "${params.AWS_REGION}"
aws_profile    = "${params.AWS_PROFILE}"

engine_version = "\$ENGINE_VERSION"
instance_type  = "\$INSTANCE_TYPE"
instance_count = \$INSTANCE_COUNT

availability_zones    = \$AZS
dedicated_master      = \$MASTER_ENABLED
master_instance_type  = "\$MASTER_TYPE"
master_instance_count = \$MASTER_COUNT

volume_type = "\$VOLUME_TYPE"
volume_size = \$VOLUME_SIZE
iops        = \$IOPS
throughput  = \$THROUGHPUT

ultrawarm_enabled   = \$WARM_ENABLED
warm_instance_type  = "\$WARM_TYPE"
warm_instance_count = \$WARM_COUNT

encrypt_at_rest           = \$ENCRYPT
node_to_node_encryption   = \$NODE_ENC
enforce_https             = \$HTTPS
advanced_security_enabled = \$ADV_SEC

custom_endpoint_enabled = \$CUSTOM_EP
custom_endpoint         = "\$CUSTOM_EP_VAL"
certificate_arn         = "\$CERT_ARN"

vpc_id            = "\$VPC_ID"
subnet_ids        = \$SUBNET_IDS
security_group_id = "\$SG_ID"
kms_key_id        = "\$KMS_KEY"

tags = {}
TFEOF
                        echo "TFVars generated from live AWS config:"
                        cat "${env.TF_VAR_file}"
                    """
                }
            }
        }

        // ─────────────────────────────────────────────
        // 5. REVIEW & EDIT PARAMETERS
        //    Shows the full tfvars file as an editable
        //    text area. User modifies values and checks
        //    CONFIRM to proceed.
        // ─────────────────────────────────────────────
        stage('Review & Edit Parameters') {
            when {
                expression { params.OPERATION in ['apply', 'plan'] && !params.AUTO_APPROVE }
            }
            steps {
                script {
                    def currentContent = ''

                    if (fileExists(env.TF_VAR_file)) {
                        currentContent = readFile(env.TF_VAR_file)
                    } else {
                        // Default template for a new cluster
                        currentContent = """\
domain_name    = "${params.DOMAIN_NAME}"
aws_region     = "${params.AWS_REGION}"
region_name    = "${params.AWS_REGION}"
aws_profile    = "${params.AWS_PROFILE}"

engine_version = "OpenSearch_2.13"
instance_type  = "m6g.large.search"
instance_count = 1

availability_zones    = ["${params.AWS_REGION}a"]
dedicated_master      = false
master_instance_type  = ""
master_instance_count = 0

volume_type = "gp3"
volume_size = 100
iops        = 3000
throughput  = 125

ultrawarm_enabled   = false
warm_instance_type  = ""
warm_instance_count = 0

encrypt_at_rest           = true
node_to_node_encryption   = true
enforce_https             = true
advanced_security_enabled = false

custom_endpoint_enabled = false
custom_endpoint         = ""
certificate_arn         = ""

vpc_id            = ""
subnet_ids        = []
security_group_id = ""
kms_key_id        = ""

tags = {}"""
                    }

                    def modeLabel = env.CLUSTER_MODE ? env.CLUSTER_MODE : 'new'
                    // input() with a single parameter returns the value directly (not a map)
                    def tfvarsContent = input(
                        id: 'EditParameters',
                        message: "📝 Review & Edit Parameters — '${params.DOMAIN_NAME}' (${modeLabel} cluster)\nEdit the tfvars below, then click 'Save & Continue':",
                        ok: 'Save & Continue',
                        parameters: [
                            text(
                                name: 'TFVARS_CONTENT',
                                defaultValue: currentContent,
                                description: 'Full tfvars content — edit any values before applying. Click Abort to cancel.'
                            )
                        ]
                    )

                    // Write the edited content back to the tfvars file
                    writeFile(file: env.TF_VAR_file, text: tfvarsContent)
                    echo "=== Final Parameters Written to ${env.TF_VAR_file} ==="
                    sh "cat '${env.TF_VAR_file}'"
                }
            }
        }

        // ─────────────────────────────────────────────
        // 6. INITIALIZE TERRAFORM
        // ─────────────────────────────────────────────
        stage('Initialize') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                dir('terraform') {
                    sh 'terraform init -input=false'
                }
            }
        }

        // ─────────────────────────────────────────────
        // 7. MANUAL IMPORT (explicit import operation)
        // ─────────────────────────────────────────────
        stage('Import Existing Cluster') {
            when {
                expression { params.OPERATION == 'import' }
            }
            steps {
                sh """
                    chmod +x scripts/import-existing-cluster.sh
                    ./scripts/import-existing-cluster.sh \
                        "${params.DOMAIN_NAME}" \
                        "${params.AWS_REGION}"  \
                        "${env.TF_VAR_file}"
                """
            }
        }

        // ─────────────────────────────────────────────
        // 8. AUTO-IMPORT (apply on existing cluster)
        //    Checks if domain is already in Terraform
        //    state; imports it if not.
        // ─────────────────────────────────────────────
        stage('Auto-Import') {
            when {
                expression { params.OPERATION == 'apply' && env.CLUSTER_MODE == 'existing' }
            }
            steps {
                script {
                    dir('terraform') {
                        echo "=== Checking Terraform State ==="
                        def inState = sh(
                            script: "terraform state show aws_opensearch_domain.main > /dev/null 2>&1 && echo 'yes' || echo 'no'",
                            returnStdout: true
                        ).trim()

                        if (inState == 'no') {
                            echo "Domain not in Terraform state — importing now..."
                            sh """
                                terraform import \
                                    -var-file="../${env.TF_VAR_file}" \
                                    aws_opensearch_domain.main \
                                    ${params.DOMAIN_NAME} || true
                            """
                        } else {
                            echo "✅ Domain already in Terraform state — skipping import"
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 9. PLAN & VALIDATE
        //    Runs terraform plan, captures exit code,
        //    and flags destructive changes.
        // ─────────────────────────────────────────────
        stage('Plan & Validate') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                script {
                    dir('terraform') {
                        def planExit = sh(
                            script: """
                                terraform plan \
                                    -var-file="../${env.TF_VAR_file}" \
                                    -out=tfplan \
                                    -input=false \
                                    -detailed-exitcode 2>&1 | tee /tmp/tf-plan.txt
                                exit \${PIPESTATUS[0]}
                            """,
                            returnStatus: true
                        )

                        env.PLAN_EXIT_CODE = planExit.toString()

                        def planText       = readFile('/tmp/tf-plan.txt')
                        env.HAS_DESTRUCTIVE = (planText.contains('will be destroyed') || planText.contains('must be replaced')).toString()

                        def summary = sh(
                            script: "grep -E '^Plan:|^No changes' /tmp/tf-plan.txt || true",
                            returnStdout: true
                        ).trim()

                        if (planExit == 0) {
                            echo "✅ No changes — infrastructure already matches configuration"
                        } else if (planExit == 2) {
                            echo "📋 ${summary}"
                            if (env.HAS_DESTRUCTIVE == 'true') {
                                echo "⚠️  WARNING: Plan contains DESTRUCTIVE changes (destroy / must-replace)!"
                            }
                        } else {
                            error("Terraform plan failed with exit code ${planExit} — review output above")
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 10. CONFIRM APPLY
        //     Shows the plan summary and requires an
        //     explicit checkbox confirmation before
        //     applying. Highlights destructive changes.
        // ─────────────────────────────────────────────
        stage('Confirm Apply') {
            when {
                expression {
                    params.OPERATION == 'apply' &&
                    !params.AUTO_APPROVE       &&
                    env.PLAN_EXIT_CODE == '2'
                }
            }
            steps {
                script {
                    def summary = sh(
                        script: "grep -E '^Plan:' /tmp/tf-plan.txt || echo 'Changes detected (see plan output above)'",
                        returnStdout: true
                    ).trim()

                    def isDestructive = env.HAS_DESTRUCTIVE == 'true'

                    def confirmMsg = isDestructive
                        ? "⚠️  DESTRUCTIVE CHANGES DETECTED\n${summary}\n\nSome resources will be DESTROYED or REPLACED — this may cause downtime."
                        : "✅ Safe to apply\n${summary}"

                    def confirmLabel = isDestructive
                        ? '⚠️  I understand resources will be destroyed/replaced — proceed anyway'
                        : 'Confirm — apply these changes now'

                    // Proceed button = apply, Abort button = cancel (no extra checkbox needed)
                    input(
                        id: 'ConfirmApply',
                        message: confirmMsg,
                        ok: confirmLabel
                    )
                }
            }
        }

        // ─────────────────────────────────────────────
        // 11. APPLY
        // ─────────────────────────────────────────────
        stage('Apply') {
            when {
                expression { params.OPERATION == 'apply' && env.PLAN_EXIT_CODE == '2' }
            }
            steps {
                dir('terraform') {
                    sh 'terraform apply -input=false tfplan'
                }
            }
        }

        // ─────────────────────────────────────────────
        // 12. MONITOR DOMAIN HEALTH
        //     Polls AWS every 30 s until Processing=False
        //     or until a 30-minute timeout is reached.
        // ─────────────────────────────────────────────
        stage('Monitor Domain Health') {
            when {
                expression { params.OPERATION == 'apply' && env.PLAN_EXIT_CODE == '2' }
            }
            steps {
                sh """
                    echo "=== Monitoring Domain Health (polling every 30s, max 30 min) ==="
                    MAX=60
                    i=0
                    while [ \$i -lt \$MAX ]; do
                        STATUS=\$(aws opensearch describe-domain \\
                            --domain-name ${params.DOMAIN_NAME} \\
                            --region      ${params.AWS_REGION}  \\
                            --profile     ${params.AWS_PROFILE} \\
                            --query       'DomainStatus.Processing' \\
                            --output      text 2>/dev/null || echo "unknown")

                        ELAPSED=\$(( i * 30 ))

                        if [ "\$STATUS" = "False" ]; then
                            echo "✅ Domain is healthy and stable! [\${ELAPSED}s elapsed]"
                            echo ""
                            echo "=== Final Domain Status ==="
                            aws opensearch describe-domain \\
                                --domain-name ${params.DOMAIN_NAME} \\
                                --region      ${params.AWS_REGION}  \\
                                --profile     ${params.AWS_PROFILE} \\
                                --query 'DomainStatus.{EngineVersion: EngineVersion, Endpoint: Endpoint, CustomEndpoint: DomainEndpointOptions.CustomEndpoint, Processing: Processing}' \\
                                --output table
                            break
                        else
                            echo "⏳ [\${ELAPSED}s] Processing=\${STATUS} — next check in 30s..."
                            sleep 30
                        fi
                        i=\$(( i + 1 ))
                    done

                    if [ \$i -ge \$MAX ]; then
                        echo "⚠️  Monitoring timed out after \$(( MAX * 30 ))s — verify status in AWS Console"
                    fi
                """
            }
        }

        // ─────────────────────────────────────────────
        // 13. VALIDATE (standalone operation)
        // ─────────────────────────────────────────────
        stage('Validate') {
            when {
                expression { params.OPERATION == 'validate' }
            }
            steps {
                sh """
                    echo "=== Validating Deployment ==="
                    PROCESSING=\$(aws opensearch describe-domain \\
                        --domain-name ${params.DOMAIN_NAME} \\
                        --region      ${params.AWS_REGION}  \\
                        --profile     ${params.AWS_PROFILE} \\
                        --query       'DomainStatus.Processing' \\
                        --output      text 2>/dev/null || echo "unknown")

                    if [ "\$PROCESSING" = "False" ]; then
                        echo "✅ Domain is healthy and stable"
                    elif [ "\$PROCESSING" = "True" ]; then
                        echo "⚠️  Domain is currently processing changes"
                    else
                        echo "❌ Could not reach domain — check credentials and region"
                        exit 1
                    fi

                    echo ""
                    echo "=== Domain Details ==="
                    aws opensearch describe-domain \\
                        --domain-name ${params.DOMAIN_NAME} \\
                        --region      ${params.AWS_REGION}  \\
                        --profile     ${params.AWS_PROFILE} \\
                        --query 'DomainStatus.{EngineVersion: EngineVersion, Endpoint: Endpoint, CustomEndpoint: DomainEndpointOptions.CustomEndpoint, Processing: Processing, InstanceType: ClusterConfig.InstanceType, InstanceCount: ClusterConfig.InstanceCount}' \\
                        --output table
                """
            }
        }

        // ─────────────────────────────────────────────
        // 14. BACKUP STATE
        // ─────────────────────────────────────────────
        stage('Backup State') {
            when {
                expression { params.OPERATION in ['apply', 'backup-state'] }
            }
            steps {
                sh '''
                    chmod +x scripts/backup-state-to-github.sh
                    ./scripts/backup-state-to-github.sh
                '''
            }
        }

    } // end stages

    post {
        always {
            archiveArtifacts artifacts: 'backup-*.json',    allowEmptyArchive: true
            archiveArtifacts artifacts: 'terraform/tfplan', allowEmptyArchive: true
        }
        success {
            echo "✅ Pipeline completed successfully — domain: ${params.DOMAIN_NAME} | region: ${params.AWS_REGION}"
        }
        failure {
            echo "❌ Pipeline failed — review the stage logs above for details"
        }
    }
}
