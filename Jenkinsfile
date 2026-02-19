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
        TOOLS_PATH = "/usr/local/bin:/opt/homebrew/bin"
        GIT_REPO = "/Users/myeredla/Documents/opensearch-ireland-infrastructure"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    export PATH="${TOOLS_PATH}:$PATH"
                    if [ ! -d "$STATE_REPO_PATH" ]; then
                        git clone https://github.com/manideepyeredla1326/opensearch-ireland-infrastructure.git $STATE_REPO_PATH
                    else
                        cd $STATE_REPO_PATH && git pull origin main
                    fi
                '''
            }
        }
        
        stage('Setup Tools') {
            steps {
                sh '''
                    export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

                    echo "Verifying tools..."

                    if ! command -v terraform &> /dev/null; then
                        echo "ERROR: Terraform not found. Run: brew install terraform"
                        exit 1
                    fi
                    echo "terraform: $(terraform version | head -1)"

                    if ! command -v aws &> /dev/null; then
                        echo "ERROR: AWS CLI not found. Run: brew install awscli"
                        exit 1
                    fi
                    echo "aws: $(aws --version)"

                    if ! command -v jq &> /dev/null; then
                        echo "ERROR: jq not found. Run: brew install jq"
                        exit 1
                    fi
                    echo "jq: $(jq --version)"

                    echo "All tools ready"
                '''
            }
        }
        
        stage('Import Existing Cluster') {
            when {
                expression { params.OPERATION == 'import' }
            }
            steps {
                sh """
                    export PATH="/usr/local/bin:/opt/homebrew/bin:\$PATH"
                    export AWS_PROFILE="${params.AWS_PROFILE}"
                    chmod +x scripts/import-existing-cluster.sh
                    ./scripts/import-existing-cluster.sh "${params.DOMAIN_NAME}" "${params.AWS_REGION}" "${env.TF_VAR_file}"
                """
            }
        }
        
        stage('Initialize') {
            when {
                expression { params.OPERATION in ['validate', 'plan', 'apply'] }
            }
            steps {
                dir('terraform') {
                    sh '''
                        export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
                        terraform init -input=false
                    '''
                }
            }
        }
        
        stage('Validate') {
            when {
                expression { params.OPERATION == 'validate' }
            }
            steps {
                sh '''
                    export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
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
                        export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
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
                    def userInput = true
                    if (!params.AUTO_APPROVE) {
                        userInput = input(
                            id: 'Proceed',
                            message: 'Apply changes to OpenSearch cluster?',
                            parameters: [
                                [$class: 'BooleanParameterDefinition',
                                 defaultValue: false,
                                 description: 'Proceed with apply',
                                 name: 'Apply']
                            ]
                        )
                    }
                    
                    if (userInput) {
                        dir('terraform') {
                            sh '''
                                export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
                                terraform apply -input=false tfplan
                            '''
                        }
                        
                        sh '''
                            export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
                            chmod +x scripts/backup-state-to-github.sh
                            ./scripts/backup-state-to-github.sh
                        '''
                    }
                }
            }
        }
        
        stage('Backup State') {
            when {
                expression { params.OPERATION == 'backup-state' }
            }
            steps {
                sh '''
                    export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
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
                    echo "OpenSearch cluster successfully imported into Terraform management"
                }
            }
        }
    }
}
