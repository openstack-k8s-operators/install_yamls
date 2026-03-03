#!/bin/bash

set -e

CEPH_NAMESPACE="rook-ceph"
NODE_NAME="crc"
LOOP_INDEX="${1:-1}"
DISK_SIZE="${2:-7}"

oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CEPH_NAMESPACE}
EOF

oc apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ceph-loop-setup
  namespace: ${CEPH_NAMESPACE}
data:
  ceph-lvm-setup.sh: |
    #!/bin/bash

    index=\${1:-"${LOOP_INDEX}"}
    size=\${2:-"${DISK_SIZE}"}

    function setup_loopback {
        major=\$(grep loop /proc/devices | cut -c3)
        mknod /dev/loop"\${index}" b "\${major}" "\${index}" 2>/dev/null || true
    }

    function build_ceph_osd {
        dd if=/dev/zero of=/var/lib/ceph-osd-"\${index}".img bs=1 count=0 seek="\${size}"G
        losetup /dev/loop"\${index}" /var/lib/ceph-osd-"\${index}".img
        pvcreate /dev/loop"\${index}"
        vgcreate ceph_vg_"\${index}" /dev/loop"\${index}"
        lvcreate -n ceph_lv_data -l +100%FREE ceph_vg_"\${index}"
    }

    function clean_ceph_osd {
        lvremove --force /dev/ceph_vg_"\${index}"/ceph_lv_data 2>/dev/null || true
        vgremove --force ceph_vg_"\${index}" 2>/dev/null || true
        pvremove --force /dev/loop"\${index}" 2>/dev/null || true
        losetup -d /dev/loop"\${index}" 2>/dev/null || true
        rm -f /var/lib/ceph-osd-"\${index}".img
        partprobe 2>/dev/null || true
    }

    setup_loopback "\${index}"
    clean_ceph_osd "\${index}"
    build_ceph_osd "\${index}"
EOF

# ServiceAccount
oc apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ceph-loop-setup
  namespace: ${CEPH_NAMESPACE}
EOF

# Role
oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ceph-loop-setup
  namespace: ${CEPH_NAMESPACE}
rules:
- apiGroups:
  - security.openshift.io
  resourceNames:
  - anyuid
  - privileged
  resources:
  - securitycontextconstraints
  verbs:
  - use
EOF

# RoleBinding
oc apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ceph-loop-setup-rolebinding
  namespace: ${CEPH_NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ceph-loop-setup
subjects:
- kind: ServiceAccount
  name: ceph-loop-setup
  namespace: ${CEPH_NAMESPACE}
EOF

# Add privileged SCC
oc adm policy add-scc-to-user privileged -z ceph-loop-setup -n ${CEPH_NAMESPACE}

# Delete job if exists
oc delete job ceph-loop-setup -n ${CEPH_NAMESPACE} 2>/dev/null || true

# Job
oc apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ceph-loop-setup
  namespace: ${CEPH_NAMESPACE}
spec:
  template:
    spec:
      hostPID: true
      hostNetwork: true
      nodeSelector:
        kubernetes.io/hostname: "${NODE_NAME}"
      serviceAccountName: ceph-loop-setup
      containers:
        - name: setup-loop
          image: quay.io/openstack-k8s-operators/bash:latest
          securityContext:
            runAsUser: 0
            privileged: true
            allowPrivilegeEscalation: true
          command:
            - /bin/sh
            - -c
            - |
              cat > /host/etc/systemd/system/ceph-lvm-setup.service << 'UNIT'
              [Unit]
              Description=Ceph OSD losetup
              After=syslog.target

              [Service]
              Type=oneshot
              ExecStart=/usr/local/bin/ceph-lvm-setup.sh
              RemainAfterExit=yes

              [Install]
              WantedBy=multi-user.target
              UNIT

              cp /mnt/ceph-lvm-setup.sh /host/usr/local/bin/ceph-lvm-setup.sh
              chmod +x /host/usr/local/bin/ceph-lvm-setup.sh

              chroot /host systemctl daemon-reload
              chroot /host systemctl enable ceph-lvm-setup.service
              chroot /host systemctl start ceph-lvm-setup.service
          volumeMounts:
            - name: host
              mountPath: /host
            - name: dev
              mountPath: /dev
            - name: ceph-loop-setup
              mountPath: /mnt
      restartPolicy: Never
      volumes:
        - name: host
          hostPath:
            path: /
        - name: dev
          hostPath:
            path: /dev
        - name: ceph-loop-setup
          configMap:
            name: ceph-loop-setup
  backoffLimit: 5
EOF

echo "Waiting for job to complete..."
oc wait --for=condition=complete job/ceph-loop-setup -n ${CEPH_NAMESPACE} --timeout=120s
