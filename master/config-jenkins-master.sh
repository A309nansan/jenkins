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
for cmd in docker stat wget sudo sed; do
  if ! command -v "$cmd" &>/dev/null; then
    log "필수 명령어 '$cmd'를 찾을 수 없습니다. 스크립트를 종료합니다."
    exit 1
  fi
done

# 작업 디렉토리로 이동
WORKDIR="/var/jenkins-master"
log "작업 디렉토리 ${WORKDIR}로 이동 중."
cd "$WORKDIR" || { log "디렉토리 이동 실패: ${WORKDIR}"; exit 1; }

# update-center-rootCAs 디렉토리 생성
log "디렉토리 'update-center-rootCAs' 생성 또는 확인 중."
mkdir -p update-center-rootCAs

# 인증서 다운로드
CERT_URL=https://cdn.jsdelivr.net/gh/lework/jenkins-update-center/rootCA/update-center.crt
CERT_DEST=/var/jenkins-master/update-center-rootCAs/update-center.crt
log "인증서를 ${CERT_URL}에서 다운로드하여 ${CERT_DEST}에 저장 중."
wget -q ${CERT_URL} -O ${CERT_DEST}
log "인증서 다운로드 완료."

# UpdateCenter XML 파일 수정 (파일이 존재하는 경우에만)
ORIGIN_URL=https://updates.jenkins.io/update-center.json
NEW_URL=https://raw.githubusercontent.com/lework/jenkins-update-center/master/updates/tencent/update-center.json
UPDATE_XML=/var/jenkins-master/hudson.model.UpdateCenter.xml
sudo sed -i "s#${ORIGIN_URL}#${NEW_URL}#" ${UPDATE_XML}

# Jenkins Docker 컨테이너 재시작
log "Jenkins Docker 컨테이너 'jenkins-master' 재시작 중."
docker restart jenkins-master

echo "작업이 완료되었습니다."
