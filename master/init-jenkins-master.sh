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

echo "작업이 완료되었습니다."
