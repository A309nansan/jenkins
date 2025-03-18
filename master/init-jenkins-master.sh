#!/bin/bash
set -euo pipefail  # 명령어 실패 시 스크립트 종료

# 로그 출력 함수
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# 에러 발생 시 로그와 함께 종료하는 함수
error() {
  log "Error on line $1"
  exit 1
}

trap 'error $LINENO' ERR

log "스크립트 실행 시작."

# 필수 명령어 확인
for cmd in docker docker-compose stat wget sudo sed; do
  if ! command -v "$cmd" &>/dev/null; then
    log "필수 명령어 '$cmd'를 찾을 수 없습니다. 스크립트를 종료합니다."
    exit 1
  fi
done

# docker network 생성 (이미 존재하면 스킵)
if docker network ls --format '{{.Name}}' | grep -q '^jenkins-network$'; then
  log "Docker network 'jenkins-network'가 이미 존재합니다. 생성 스킵."
else
  log "Docker network 'jenkins-network' 생성 중."
  docker network create --driver bridge jenkins-network
fi

# jenkins-master 이미지 빌드
log "jenkins-master 이미지 빌드 시작."
docker build -t jenkins-master:latest .

# jenkins 작업 공간을 mount할 폴더 미리 생성
log "jenkins-master의 volume을 mount할 Host Machine에 /var/jenkins-master 만드는중..."
sudo mkdir -p /var/jenkins-master
sudo chown -R 1000:1000 /var/jenkins-master

# Docker 소켓의 그룹 ID를 가져와 환경변수에 저장
if [ -e /var/run/docker.sock ]; then
  export DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
  log "DOCKER_GID가 ${DOCKER_GID}(으)로 설정되었습니다."
else
  log "Docker 소켓(/var/run/docker.sock)을 찾을 수 없습니다. 스크립트를 종료합니다."
  exit 1
fi

# Docker Compose로 서비스 실행
log "Docker Compose로 서비스 실행 중..."
docker compose up -d

# 작업 디렉토리로 이동
WORKDIR="/var/jenkins-master"
log "작업 디렉토리 ${WORKDIR}로 이동 중."
cd "$WORKDIR" || { log "디렉토리 이동 실패: ${WORKDIR}"; exit 1; }

# update-center-rootCAs 디렉토리 생성
log "디렉토리 'update-center-rootCAs' 생성 또는 확인 중."
mkdir -p update-center-rootCAs

# 인증서 다운로드
CERT_URL="https://cdn.jsdelivr.net/gh/lework/jenkins-update-center/rootCA/update-center.crt"
CERT_DEST="./update-center-rootCAs/update-center.crt"
log "인증서를 ${CERT_URL}에서 다운로드하여 ${CERT_DEST}에 저장 중."
wget -q "$CERT_URL" -O "$CERT_DEST"
log "인증서 다운로드 완료."

# UpdateCenter XML 파일 수정 (파일이 존재하는 경우에만)
UPDATE_XML=/var/jenkins-master/hudson.model.UpdateCenter.xml
if [ -f "$UPDATE_XML" ]; then
  log "${UPDATE_XML} 파일의 업데이트 센터 URL 수정 중."
  sudo sed -i 's#https://updates.jenkins.io/update-center.json#https://raw.githubusercontent.com/lework/jenkins-update-center/master/updates/tencent/update-center.json#' "$UPDATE_XML"
else
  log "${UPDATE_XML} 파일을 찾을 수 없어 수정 스킵."
fi

# Jenkins Docker 컨테이너 재시작
log "Jenkins Docker 컨테이너 'jenkins-master' 재시작 중."
sudo docker restart jenkins-master

echo "작업이 완료되었습니다."
