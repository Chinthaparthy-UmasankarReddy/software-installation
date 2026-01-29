**MongoDB ReplicaSet + Spring Boot with NFS PersistentVolume (PV)**

## 1. Setup NFS Server (On separate host)
```bash
# On NFS server (e.g., 192.168.1.100)
sudo apt update
sudo apt install nfs-kernel-server

# Create export directory
sudo mkdir -p /mnt/nfs-mongo
sudo chown 999:999 /mnt/nfs-mongo
sudo chmod 777 /mnt/nfs-mongo

# Edit /etc/exports
echo "/mnt/nfs-mongo *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# Export and restart
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

## Why Required
Kubernetes kubelet uses the host system's NFS client (`mount.nfs` from nfs-common package) to mount NFS volumes into pods. Without it:
- Pod stays in `ContainerCreating` forever
- `kubectl describe pod` shows "mount failed: exit status 32" OR hangs silently
- Even with correct NFS server IP, ports open, exports configured [itnext](https://itnext.io/having-your-kubernetes-over-nfs-0510d5ed9b0b)

Your earlier error ("bad option; ... need /sbin/mount.nfs helper") was exactly this missing package.

## Ubuntu/Debian Nodes (Your Case)
```bash
# Run on EVERY worker node (ip-10-0-1-120, ip-10-0-1-210, ip-10-0-1-10)
sudo apt update
sudo apt install -y nfs-common
dpkg -l | grep nfs-common  # Verify: ii nfs-common
```

## Verification (Post-Install)
```bash
# Test from each worker node to your NFS server (10.0.1.10)
showmount -e 10.0.1.10
sudo mount -t nfs 10.0.1.10:/mnt/nfs-mongo /tmp/nfs-test
sudo umount /tmp/nfs-test
```


## 2. Complete YAML (`nfs-pv-app.yml`)
```yaml
---
# NFS PersistentVolume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-nfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs-storage
  nfs:
    server: 192.168.1.100      # YOUR NFS SERVER IP
    path: /mnt/nfs-mongo

---
# PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-nfs-pvc
spec:
  storageClassName: nfs-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi

---
# MongoDB ReplicaSet with NFS
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: mongodbrs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo
        image: mongo:7.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: devdb
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: devdb123
        - name: MONGO_INITDB_DATABASE
          value: myappdb
        volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
      volumes:
      - name: mongo-storage
        persistentVolumeClaim:
          claimName: mongo-nfs-pvc

---
# MongoDB Service
apiVersion: v1
kind: Service
metadata:
  name: mongosvc
spec:
  type: ClusterIP
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017

---
# Spring Boot Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springappdeployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: springapp
  template:
    metadata:
      labels:
        app: springapp
    spec:
      containers:
      - name: springapp
        image: dockeruma03/spring-boot-mongo:1
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_DATA_MONGODB_HOST
          value: mongosvc
        - name: SPRING_DATA_MONGODB_PORT
          value: "27017"
        - name: SPRING_DATA_MONGODB_USERNAME
          value: devdb
        - name: SPRING_DATA_MONGODB_PASSWORD
          value: devdb123
        - name: SPRING_DATA_MONGODB_DATABASE
          value: myappdb
        - name: SPRING_DATA_MONGODB_AUTHENTICATION_DATABASE
          value: admin

---
# Spring Boot Service
apiVersion: v1
kind: Service
metadata:
  name: springappsvc
spec:
  type: NodePort
  selector:
    app: springapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 32577
```

## Deploy
```bash
# UPDATE NFS SERVER IP in YAML first!
kubectl delete all --all -l app=springapp,app=mongo
kubectl apply -f nfs-pv-app.yml

# Verify
kubectl get all,pv,pvc
```

## Expected Status
```
PV:      mongo-nfs-pv        Bound    10Gi    RWO    nfs-storage
PVC:     mongo-nfs-pvc       Bound
Mongo:   mongodbrs-xxx       1/1 Running
Spring:  springappdeployment 2/2 READY
```

## NFS Advantages
✅ **Multi-node access** (RWX capable)  
✅ **Network storage** (works across nodes)  
✅ **Centralized management**  
✅ **Data survives** node failures  
✅ **No hostPath limitations**

**Replace `192.168.1.100` with your actual NFS server IP!** Access app at `http://10.0.1.129:32577` 🎉
