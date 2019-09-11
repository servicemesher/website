---
originallink: "https://labs.meanpug.com/custom-application-metrics-with-django-prometheus-and-kubernetes/"
author: "Bobby Steinbach"
date: "2019-09-12T18:00:00+08:00"
draft: false
banner: "/img/blog/banners/006tKfTcgy1ftnl1osmwjj30rs0kub1t.jpg"
translator: "马若飞"
translatorlink: "https://github.com/malphi"
reviewer:  ["孙海洲"]
reviewerlink:  ["https://github.com/haiker2011"]
title: "使用Django, Prometheus, 和 Kubernetes定制应用指标"
description: "本文演示了如何在AWS控制台创建一个App Mesh"
categories: ["service mesh"]
tags: ["service mesh"]
---

## 编者按

//todo

### Why are custom metrics important?

While there are volumes of discourse on the topic, it can't be overstated how important custom application metrics are. Unlike the core service metrics you'll want to collect for your Django application (application and web server stats, key DB and cache operational metrics), custom metrics are data points unique to your domain with bounds and thresholds known only by you. In other words, it's the fun stuff.

尽管有大量关于这个主题的论述，但是定制应用程序度量的重要性怎么强调都不为过。与您希望为Django应用程序收集的核心服务指标(应用程序和web服务器统计数据、关键数据库和缓存操作指标)不同，自定义指标是域特有的数据点，其边界和阈值只有您自己知道。换句话说，这是有趣的东西。

How might these metrics be useful? Consider:

- You run an ecomm website and track average order size. Suddenly that order size isn't so average. With solid application metrics and monitoring you can catch the bug before it [breaks the bank](https://dealbook.nytimes.com/2012/08/02/knight-capital-says-trading-mishap-cost-it-440-million/).
- You're writing a scraper that pulls the most recent articles from a news website every hour. Suddenly the most recent articles aren't so recent. Solid metrics and monitoring will reveal the breakage earlier.
- I 👏 Think 👏 You 👏 Get 👏 The 👏 Point 👏

### Setting up the Django Application

Besides the obvious dependencies (looking at you `pip install Django`), we'll need some additional packages for our pet project. Go ahead and `pip install django-prometheus-client`. This will give us a Python Prometheus client to play with, as well as some helpful Django hooks including middleware and a nifty DB wrapper. Next we'll run the Django management commands to start a project and app, update our settings to utilize the Prometheus client, and add Prometheus URLs to our URL conf.

*Start a new project and app*
For the purposes of this post, and in fitting with our [agency brand](https://www.meanpug.com/), we'll be building a dog walking service. Mind you, it won't actually do much, but should suffice to serve as a teaching tool. Go ahead and execute:

除了明显的依赖关系(看看您安装Django的pip)之外，我们还需要为我们的宠物项目添加一些额外的包。继续并pip安装django-prometheus-client。这将为我们提供一个可以使用的Python Prometheus客户机，以及一些有用的Django钩子，包括中间件和一个漂亮的DB包装器。接下来，我们将运行Django管理命令来启动一个项目和应用程序，更新我们的设置来使用Prometheus客户机，并将Prometheus URL添加到我们的URL conf中。

启动一个新的项目和应用程序
为了这篇文章的目的，并且符合我们的代理品牌，我们将建立一个遛狗服务。请注意，它实际上不会做太多，但应该足以作为一个教学工具。继续执行:

```bash
django-admin.py startproject demo
python manage.py startapp walker
#settings.py

INSTALLED_APPS = [
    ...
    'walker',
    ...
]
```

Now, we'll add some basic models and views. For the sake of brevity, I'll only include implementation for the portions we'll be instrumenting, but if you'd like to follow along in full just grab the [demo app](https://github.com/MeanPug/django-prometheus-demo) source.

现在，我们将添加一些基本模型和视图。为了简单起见，我将只包含我们将要检测的部分的实现，但是如果您想要完整地理解，请获取演示应用程序源代码。

```python
# walker/models.py
from django.db import models
from django_prometheus.models import ExportModelOperationsMixin


class Walker(ExportModelOperationsMixin('walker'), models.Model):
    name = models.CharField(max_length=127)
    email = models.CharField(max_length=127)

    def __str__(self):
        return f'{self.name} // {self.email} ({self.id})'


class Dog(ExportModelOperationsMixin('dog'), models.Model):
    SIZE_XS = 'xs'
    SIZE_SM = 'sm'
    SIZE_MD = 'md'
    SIZE_LG = 'lg'
    SIZE_XL = 'xl'
    DOG_SIZES = (
        (SIZE_XS, 'xsmall'),
        (SIZE_SM, 'small'),
        (SIZE_MD, 'medium'),
        (SIZE_LG, 'large'),
        (SIZE_XL, 'xlarge'),
    )

    size = models.CharField(max_length=31, choices=DOG_SIZES, default=SIZE_MD)
    name = models.CharField(max_length=127)
    age = models.IntegerField()

    def __str__(self):
        return f'{self.name} // {self.age}y ({self.size})'


class Walk(ExportModelOperationsMixin('walk'), models.Model):
    dog = models.ForeignKey(Dog, related_name='walks', on_delete=models.CASCADE)
    walker = models.ForeignKey(Walker, related_name='walks', on_delete=models.CASCADE)

    distance = models.IntegerField(default=0, help_text='walk distance (in meters)')

    start_time = models.DateTimeField(null=True, blank=True, default=None)
    end_time = models.DateTimeField(null=True, blank=True, default=None)

    @property
    def is_complete(self):
        return self.end_time is not None
        
    @classmethod
    def in_progress(cls):
        """ get the list of `Walk`s currently in progress """
        return cls.objects.filter(start_time__isnull=False, end_time__isnull=True)

    def __str__(self):
        return f'{self.walker.name} // {self.dog.name} @ {self.start_time} ({self.id})'
# walker/views.py
from django.shortcuts import render, redirect
from django.views import View
from django.core.exceptions import ObjectDoesNotExist
from django.http import HttpResponseNotFound, JsonResponse, HttpResponseBadRequest, Http404
from django.urls import reverse
from django.utils.timezone import now
from walker import models, forms


class WalkDetailsView(View):
    def get_walk(self, walk_id=None):
        try:
            return models.Walk.objects.get(id=walk_id)
        except ObjectDoesNotExist:
            raise Http404(f'no walk with ID {walk_id} in progress')


class CheckWalkStatusView(WalkDetailsView):
    def get(self, request, walk_id=None, **kwargs):
        walk = self.get_walk(walk_id=walk_id)
        return JsonResponse({'complete': walk.is_complete})


class CompleteWalkView(WalkDetailsView):
    def get(self, request, walk_id=None, **kwargs):
        walk = self.get_walk(walk_id=walk_id)
        return render(request, 'index.html', context={'form': forms.CompleteWalkForm(instance=walk)})

    def post(self, request, walk_id=None, **kwargs):
        try:
            walk = models.Walk.objects.get(id=walk_id)
        except ObjectDoesNotExist:
            return HttpResponseNotFound(content=f'no walk with ID {walk_id} found')

        if walk.is_complete:
            return HttpResponseBadRequest(content=f'walk {walk.id} is already complete')

        form = forms.CompleteWalkForm(data=request.POST, instance=walk)

        if form.is_valid():
            updated_walk = form.save(commit=False)
            updated_walk.end_time = now()
            updated_walk.save()

            return redirect(f'{reverse("walk_start")}?walk={walk.id}')

        return HttpResponseBadRequest(content=f'form validation failed with errors {form.errors}')


class StartWalkView(View):
    def get(self, request):
        return render(request, 'index.html', context={'form': forms.StartWalkForm()})

    def post(self, request):
        form = forms.StartWalkForm(data=request.POST)

        if form.is_valid():
            walk = form.save(commit=False)
            walk.start_time = now()
            walk.save()

            return redirect(f'{reverse("walk_start")}?walk={walk.id}')

        return HttpResponseBadRequest(content=f'form validation failed with errors {form.errors}')
```

*Update app settings and add Prometheus urls*
Now that we have a Django project and app setup, it's time to add the required settings for [django-prometheus](https://github.com/korfuri/django-prometheus). In `settings.py`, apply the following:

```python
INSTALLED_APPS = [
    ...
    'django_prometheus',
    ...
]

MIDDLEWARE = [
    'django_prometheus.middleware.PrometheusBeforeMiddleware',
    ....
    'django_prometheus.middleware.PrometheusAfterMiddleware',
]

# we're assuming a Postgres DB here because, well, that's just the right choice :)
DATABASES = {
    'default': {
        'ENGINE': 'django_prometheus.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME'),
        'USER': os.getenv('DB_USER'),
        'PASSWORD': os.getenv('DB_PASSWORD'),
        'HOST': os.getenv('DB_HOST'),
        'PORT': os.getenv('DB_PORT', '5432'),
    },
}
```

and add the following to your `urls.py`

```python
urlpatterns = [
    ...
    path('', include('django_prometheus.urls')),
]
```

At this point, we have a basic application configured and primed for instrumentation.

------

### Instrument the code with Prometheus metrics

As a result of out of box functionality provided by `django-prometheus`, we immediately have basic model operations, like insertions and deletions, tracked. You can see this in action at the `/metrics` endpoint where you'll have something like:

由于django-prometheus提供的开箱即用功能，我们可以立即跟踪基本的模型操作，比如插入和删除。您可以在/metrics端点处看到这一点，在那里您将得到如下内容:

![django-prometheus default metrics](https://labs.meanpug.com/content/images/2019/09/Screen-Shot-2019-09-07-at-12.18.47-AM.png)default metrics provided by django-prometheus

Let's make this a bit more interesting.

Start by adding a `walker/metrics.py` where we'll define some basic metrics to track.

```python
# walker/metrics.py
from prometheus_client import Counter, Histogram


walks_started = Counter('walks_started', 'number of walks started')
walks_completed = Counter('walks_completed', 'number of walks completed')
invalid_walks = Counter('invalid_walks', 'number of walks attempted to be started, but invalid')

walk_distance = Histogram('walk_distance', 'distribution of distance walked', buckets=[0, 50, 200, 400, 800, 1600, 3200])
```

Painless, eh? The [Prometheus documentation](https://prometheus.io/docs/concepts/metric_types/) does a good job explaining what each of the metric types should be used for, but in short we are using counters to represent metrics that are strictly increasing over time and histograms to track metrics that contain a distribution of values we want tracked. Let's start instrumenting our application code.

无痛,是吗?Prometheus文档很好地解释了每种度量类型的用途，但是简而言之，我们使用计数器来表示严格随时间增长的度量，使用直方图来跟踪包含我们希望跟踪的值分布的度量。让我们开始检测应用程序代码。

```python
# walker/views.py
...
from walker import metrics
...

class CompleteWalkView(WalkDetailsView):
    ...
    def post(self, request, walk_id=None, **kwargs):
        ...
        if form.is_valid():
            updated_walk = form.save(commit=False)
            updated_walk.end_time = now()
            updated_walk.save()

            metrics.walks_completed.inc()
            metrics.walk_distance.observe(updated_walk.distance)

            return redirect(f'{reverse("walk_start")}?walk={walk.id}')

        return HttpResponseBadRequest(content=f'form validation failed with errors {form.errors}')

...

class StartWalkView(View):
    ...
    def post(self, request):
        if form.is_valid():
            walk = form.save(commit=False)
            walk.start_time = now()
            walk.save()

            metrics.walks_started.inc()

            return redirect(f'{reverse("walk_start")}?walk={walk.id}')

        metrics.invalid_walks.inc()

        return HttpResponseBadRequest(content=f'form validation failed with errors {form.errors}')
```

If we make a few sample requests, we'll be able to see the new metrics flowing through the endpoint.

![custom metrics coming in](https://labs.meanpug.com/content/images/2019/09/custom-application-metrics.png)peep the walk distance and created walks metrics

![prometheus custom metrics](https://labs.meanpug.com/content/images/2019/09/custom-metrics-prometheus.png)our metrics are now available for graphing in prometheus

By this point we've defined our custom metrics in code, instrumented the application to track these metrics, and verified that the metrics are updated and available at the `/metrics` endpoint. Let's move on to deploying our instrumented application to a Kubernetes cluster.

至此，我们已经在代码中定义了自定义指标，并对应用程序进行了工具化，以跟踪这些指标，并验证了这些指标已在/metrics端点上更新并可用。让我们继续将我们的仪表化应用程序部署到Kubernetes集群。

### Deploying the application with Helm

I'll keep this part brief and limited only to configuration relevant to metric tracking and exporting, but the full Helm chart with complete deployment and service configuration may be found in the [demo app](https://github.com/MeanPug/django-prometheus-demo). As a jumping off point, here's some snippets of the deployment and configmap highlighting portions with significance towards metric exporting.

我会把这部分短暂和有限的配置相关指标跟踪和出口,但满舵图完成部署和服务配置可以在演示应用程序中找到。作为一个起点,这里有一些片段的部署和configmap突出部分与意义对度量出口。

```yaml
# helm/demo/templates/nginx-conf-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "demo.fullname" . }}-nginx-conf
  ...
data:
  demo.conf: |
    upstream app_server {
      server 127.0.0.1:8000 fail_timeout=0;
    }

    server {
      listen 80;
      client_max_body_size 4G;

      # set the correct host(s) for your site
      server_name{{ range .Values.ingress.hosts }} {{ . }}{{- end }};

      keepalive_timeout 5;

      root /code/static;

      location / {
        # checks for static file, if not found proxy to app
        try_files $uri @proxy_to_app;
      }

      location ^~ /metrics {
        auth_basic           "Metrics";
        auth_basic_user_file /etc/nginx/secrets/.htpasswd;

        proxy_pass http://app_server;
      }

      location @proxy_to_app {
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
        # we don't want nginx trying to do something clever with
        # redirects, we set the Host: header above already.
        proxy_redirect off;
        proxy_pass http://app_server;
      }
    }
```

------

```yaml
# helm/demo/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
...
    spec:
      metadata:
        labels:
          app.kubernetes.io/name: {{ include "demo.name" . }}
          app.kubernetes.io/instance: {{ .Release.Name }}
          app: {{ include "demo.name" . }}
      volumes:
        ...
        - name: nginx-conf
          configMap:
            name: {{ include "demo.fullname" . }}-nginx-conf
        - name: prometheus-auth
          secret:
            secretName: prometheus-basic-auth
        ...
      containers:
        - name: {{ .Chart.Name }}-nginx
          image: "{{ .Values.nginx.image.repository }}:{{ .Values.nginx.image.tag }}"
          imagePullPolicy: IfNotPresent
          volumeMounts:
            ...
            - name: nginx-conf
              mountPath: /etc/nginx/conf.d/
            - name: prometheus-auth
              mountPath: /etc/nginx/secrets/.htpasswd
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command: ["gunicorn", "--worker-class", "gthread", "--threads", "3", "--bind", "0.0.0.0:8000", "demo.wsgi:application"]
          env:
{{ include "demo.env" . | nindent 12 }}
          ports:
            - name: gunicorn
              containerPort: 8000
              protocol: TCP
           ...
```

Nothing too magick-y here, just your good ol' YAML blob. There are only two important points I'd like to draw attention to:

1. We put the `/metrics` endpoint behind basic auth via an nginx reverse proxy with an `auth_basic` directive set for the location block. While you'll probably want to [deploy gunicorn behind a reverse proxy](https://docs.gunicorn.org/en/latest/deploy.html) anyway, we get the added benefit of protecting our application metrics in doing so.
2. 我们通过一个nginx反向代理将/metrics端点放在basic auth后面，该代理为location块设置了auth_basic指令集。尽管您可能希望在反向代理之后部署gunicorn，但是这样做还可以获得保护应用程序指标的额外好处。
3. We use multi-threaded gunicorn as opposed to multiple workers. While you can enable [multiprocess mode](https://github.com/prometheus/client_python#multiprocess-mode-gunicorn) for the Prometheus client, it is a more complex setup in a Kubernetes environment. Why is this important? Well, the danger in running multiple workers in a single pod is that each worker will report its own set of metric values on scrape. However, since the service is grouped to the pod level in the Prometheus Kubernetes SD scrape config, these (potentially) jumping values will be incorrectly classified as [counter resets](https://prometheus.io/docs/concepts/metric_types/#counter) leading to inconsistent measurements. You don't necessarily need to follow all the above, but the big **Tl:Dr** here is: *If you don't know better, you should probably start in either a single thread + single worker gunicorn environment, or else a single worker + multi-threaded one.*
4. 我们使用多线程gunicorn，而不是多个worker。虽然您可以为Prometheus客户机启用多进程模式，但在Kubernetes环境中，这是一个更为复杂的设置。为什么这很重要?在一个pod中运行多个worker的危险之处在于，每个worker将在刮擦时报告自己的一组度量值。但是，由于服务在Prometheus Kubernetes SD刮擦配置中被分组到pod级别，这些(潜在的)跳转值将被错误地分类为计数器重置，从而导致测量结果不一致。您并不一定需要遵循上述所有步骤，但是这里的主要Tl:Dr是:如果您不了解更多，您可能应该从一个单线程+单worker gunicorn环境开始，或者从一个单线程+多线程环境开始。

### Deploying Prometheus with Helm

With the help of [Helm](https://helm.sh/), deploying Prometheus to the cluster is a 🍰. Without further ado:

```bash
helm upgrade --install prometheus stable/prometheus
```

After a few minutes, you should be able to `port-forward` into the Prometheus pod (the default container port is 9090)

### Configuring a Prometheus scrape target for the application

The [Prometheus Helm chart](https://github.com/helm/charts/tree/master/stable/prometheus) has a *ton* of customization options, but for our purposes we just need to set the `extraScrapeConfigs`. To do so, start by creating a `values.yaml`. As in most of the post, you can skip this section and just use the [demo app](https://github.com/MeanPug/django-prometheus-demo) as a prescriptive guide if you'd like. In that file, you'll want:

```yaml
extraScrapeConfigs: |
  - job_name: demo
    scrape_interval: 5s
    metrics_path: /metrics
    basic_auth:
      username: prometheus
      password: prometheus
    tls_config:
      insecure_skip_verify: true
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
            - default
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_label_app]
        regex: demo
        action: keep
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        regex: http
        action: keep
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      - source_labels: [__meta_kubernetes_service_name]
        target_label: service
      - source_labels: [__meta_kubernetes_service_name]
        target_label: job
      - target_label: endpoint
        replacement: http
```

After creating the file, you should be able to apply the update to your prometheus deployment from the previous step via

```bash
helm upgrade --install prometheus -f values.yaml
```

To verify everything worked properly, open up your browser to http://localhost:9090/targets (assuming you've already `port-forward`ed into the running prometheus server Pod). If you see the demo app there in the target list, then that's a big 👍.

### Try it yourself

I'm going to make a bold statement here: Capturing custom application metrics and setting up the corresponding reporting and monitoring is one of the most immediately gratifying tasks in software engineering. Luckily for us, it's actually *really* simple to integrate Prometheus metrics into your Django application, as I hope this post has shown. If you'd like to start instrumenting your own app, feel free to rip configuration and ideas from the [full sample application](https://github.com/MeanPug/django-prometheus-demo), or just fork the repo and hack away. Happy trails 🐶

我要在这里大胆地声明:捕获自定义应用程序度量并设置相应的报告和监视是软件工程中最令人满意的任务之一。幸运的是，将Prometheus指标集成到Django应用程序中实际上非常简单，正如我希望本文所展示的那样。如果您想要开始检测自己的应用程序，请随意从完整的示例应用程序中提取配置和思想，或者直接使用repo并删除它们。幸福的步道