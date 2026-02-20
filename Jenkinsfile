pipeline {
    agent any
    
    parameters {
        choice(
            name: 'OPERATION',
            choices: ['validate', 'plan', 'apply', 'import', 'backup-state'],
            description: 'Operation to perform'
        )
        string(
            name: 'AWS_REGION',
            defaultValue: 'eu-west-1',
            description: 'AWS region for the cluster'
        )
        string(
            name: 'DOMAIN_NAME',
            defaultValue: 'imiconnect-uk-prod',
            description: 'Name of the OpenSearch domain'
        )
        string(
            name: 'AWS_PROFILE',
            defaultValue: 'default',
            description: 'AWS profile name to use for credentials'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Auto approve terraform apply'
        )
    }
    
    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        TF_VAR_file = "regions/${params.AWS_REGION}/${params.DOMAIN_NAME}.tfvars"
        STATE_REPO_PATH = "../opensearch-terraform-state"
        GPG_RECIPIENT = 'myeredla@cisco.com'
    }
    
    stages {
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
        
        stage('Setup Tools') {
            steps {
                sh '''
                    if ! command -v terraform &> /dev/null; then
                        rm -rf terraform_1.6.0_darwin_amd64.zip terraform
                        /opt/homebrew/bin/wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_darwin_amd64.zip
                        unzip -o terraform_1.6.0_darwin_amd64.zip
                        export PATH=$PWD:$PATH
                    fi
                    terraform version
                '''
            }
        }
        
        stage('Import Existing Cluster') {
            when {
                expression { params.OPERATION == 'import' }
            }
            steps {
                sh '''
                    chmod +x scripts/import-existing-cluster.sh
                    ./scripts/import-existing-cluster.sh "${params.DOMAIN_NAME}" "${params.AWS_REGION}" "${TF_VAR_file}"
                '''
            }
        }
        
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
        
        stage('Validate') {
            when {
                expression { params.OPERATION == 'validate' }
            }
            steps {
                sh '''
                    chmod +x scripts/validate-deployment.sh
                    ./scripts/validate-deployment.sh
                '''
            }
        }
        
        stage('Plan') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                dir('terraform') {
                    sh '''
                        terraform plan \
                            -var-file="../${TF_VAR_file}" \
                            -out=tfplan \
                            -input=false
                    '''
                }
            }
        }
        
        stage('Apply') {
            when {
                expression { params.OPERATION == 'apply' }
            }
            steps {
                script {
                    def applyDomain  = params.DOMAIN_NAME
                    def applyRegion  = params.AWS_REGION
                    def applyProfile = params.AWS_PROFILE

                    if (!params.AUTO_APPROVE) {
                        def userInput = input(
                            id: 'Proceed',
                            message: 'Review and edit parameters before applying to OpenSearch cluster:',
                            parameters: [
                                string(
                                    name: 'DOMAIN_NAME',
                                    defaultValue: params.DOMAIN_NAME,
                                    description: 'OpenSearch domain name to apply changes to'
                                ),
                                string(
                                    name: 'AWS_REGION',
                                    defaultValue: params.AWS_REGION,
                                    description: 'AWS region (e.g. eu-west-1, us-east-1)'
                                ),
                                string(
                                    name: 'AWS_PROFILE',
                                    defaultValue: params.AWS_PROFILE,
                                    description: 'AWS CLI profile to use for credentials'
                                ),
                                booleanParam(
                                    name: 'CONFIRM',
                                    defaultValue: false,
                                    description: 'Check this box to confirm and proceed with apply'
                                )
                            ]
                        )

                        if (!userInput.CONFIRM) {
                            error('Apply cancelled — CONFIRM was not checked.')
                        }

                        applyDomain  = userInput.DOMAIN_NAME
                        applyRegion  = userInput.AWS_REGION
                        applyProfile = userInput.AWS_PROFILE
                    }

                    def tfVarFile = "regions/${applyRegion}/${applyDomain}.tfvars"

                    dir('terraform') {
                        sh """
                            terraform plan \\
                                -var-file="../${tfVarFile}" \\
                                -out=tfplan \\
                                -input=false
                            terraform apply -input=false tfplan
                        """
                    }

                    sh '''
                        chmod +x scripts/backup-state-to-github.sh
                        ./scripts/backup-state-to-github.sh
                    '''
                }
            }
        }
        
        stage('Backup State') {
            when {
                expression { params.OPERATION == 'backup-state' }
            }
            steps {
                sh '''
                    chmod +x scripts/backup-state-to-github.sh
                    ./scripts/backup-state-to-github.sh
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'backup-*.json', allowEmptyArchive: true
            archiveArtifacts artifacts: 'terraform/tfplan', allowEmptyArchive: true
        }
        
        success {
            script {
                if (params.OPERATION == 'import') {
                    echo "✅ OpenSearch cluster successfully imported into Terraform management"
                }
            }
        }
    }
}