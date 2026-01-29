## Modified YAML - MongoDB as Deployment with PV/PVC

Save this as `complete-app-mongo-deployment.yml`:

```yaml
---
# 1. Persistent Volume for MongoDB
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/mongo-data

---
# 2. Persistent Volume Claim for MongoDB
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual

---
# 3. MongoDB Deployment (NOT StatefulSet)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-deployment
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
      - name: mongodb
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
          claimName: mongo-pvc

---
# 4. MongoDB ClusterIP Service (For Spring Boot access)
apiVersion: v1
kind: Service
metadata:
  name: mongo-cluster-svc
spec:
  type: ClusterIP
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017

---
# 5. Spring Boot Deployment (NO probes)
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
        - name: SPRING_DATA_MONGODB_URI
          value: "mongodb://devdb:devdb123@mongo-cluster-svc:27017/myappdb?authSource=admin"
        - name: SPRING_DATA_MONGODB_DATABASE
          value: "myappdb"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"

---
# 6. Spring Boot NodePort Service
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

## Step-by-Step Deployment

### 1. Clean Previous Resources
```bash
kubectl delete all --all -l app=mongo
kubectl delete all --all -l app=springapp
kubectl delete pv mongo-pv mongo-stateful-pv || true
kubectl delete pvc mongo-pvc mongo-storage-mongodb-0 || true
```

### 2. Prepare Storage Directory
```bash
sudo mkdir -p /mnt/mongo-data
sudo chmod 777 /mnt/mongo-data
sudo chown 999:999 /mnt/mongo-data  # MongoDB runs as UID 999
```

### 3. Apply Complete Manifest
```bash
kubectl apply -f complete-app-mongo-deployment.yml
```

### 4. Verify Deployment
```bash
# Check all resources
kubectl get all

# Check storage binding
kubectl get pvc,pv

# Expected output:
# NAME                           STATUS   VOLUME    CAPACITY  ACCESS MODES  STORAGECLASS  AGE
# pvc/mongo-pvc                  Bound    mongo-pv  5Gi       RWO           manual        10s

# NAME                    READY  STATUS   RESTARTS  AGE
# pod/mongodb-deploy...   1/1    Running  0         10s
# pod/springapp...        1/1    Running  0         10s
```

### 5. Check Logs
```bash
# MongoDB initialization
kubectl logs deployment/mongodb-deployment

# Spring Boot MongoDB connection
kubectl logs -f deployment/springappdeployment
```

### 6. Test Application
```bash
# Get node IP
kubectl get nodes -o wide

# Test Spring Boot app
curl http://10.0.1.10:32577

# Port forward for local testing
kubectl port-forward svc/springappsvc 8080:80
curl http://localhost:8080
```

## Key Changes Made

1. **MongoDB Deployment**: Replaced StatefulSet with simple Deployment
2. **Volume Reference**: Uses `volumes` section with `mongo-pvc` instead of `volumeClaimTemplates`
3. **Removed**: Headless service (not needed for Deployment)
4. **Removed**: Liveness/readiness probes from Spring Boot
5. **Simplified**: Single MongoDB replica with direct PV/PVC binding

## Expected Final Status
```
NAME                            READY  STATUS
pod/mongodb-deployment-...      1/1    Running
pod/springappdeployment-...     1/1    Running
pod/springappdeployment-...     1/1    Running

NAME                    STATUS  VOLUME
pvc/mongo-pvc           Bound   mongo-pv

NAME                           TYPE       PORT(S)
svc/mongo-cluster-svc          ClusterIP  27017/TCP
svc/springappsvc               NodePort   80:32577/TCP
```

**Your app will be accessible at `http://10.0.1.10:32577`** with MongoDB data persisted in `/mnt/mongo-data` on the node.
