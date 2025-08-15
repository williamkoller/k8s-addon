package main

import (
	"flag"
	"fmt"
	"os"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"

	"github.com/williamkoller/k8s-addon/internal/controllers"
)

var (
	scheme = runtime.NewScheme()
)

func init() {
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))
}

func main() {
	var metricsAddr string
	var probeAddr string
	var leaderElect bool
	var maxConcurrentReconciles int
	var enableConcurrencyOptimizations bool

	flag.StringVar(&metricsAddr, "metrics-bind-address", ":8080", "The address the metric endpoint binds to.")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
	flag.BoolVar(&leaderElect, "leader-elect", true, "Enable leader election for controller manager.")
	flag.IntVar(&maxConcurrentReconciles, "max-concurrent-reconciles", 5, "The maximum number of concurrent reconciles per controller.")
	flag.BoolVar(&enableConcurrencyOptimizations, "enable-concurrency-optimizations", true, "Enable concurrency optimizations in controllers.")
	opts := zap.Options{Development: false}
	opts.BindFlags(flag.CommandLine)
	flag.Parse()

	logger := zap.New(zap.UseFlagOptions(&opts))
	ctrl.SetLogger(logger)

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme: scheme,
		Metrics: metricsserver.Options{
			BindAddress: metricsAddr,
		},
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         leaderElect,
		LeaderElectionID:       "k8s-addon.yourorg.io",
	})
	if err != nil {
		panic(fmt.Errorf("cannot create manager: %w", err))
	}

	// Configs via env
	ownerKey := getEnv("OWNER_LABEL_KEY", "owner")
	ownerVal := getEnv("OWNER_LABEL_VALUE", "platform")
	taintKey := getEnv("GPU_TAINT_KEY", "nvidia.com/gpu")
	taintVal := getEnv("GPU_TAINT_VALUE", "true")
	taintEffect := getEnv("GPU_TAINT_EFFECT", "NoSchedule")
	gpuNodeLabelKey := getEnv("GPU_NODE_LABEL_KEY", "gpu")
	gpuNodeLabelVal := getEnv("GPU_NODE_LABEL_VALUE", "true")

	// Setup NamespaceReconciler com configurações de concorrência
	nsReconciler := &controllers.NamespaceReconciler{
		Client:   mgr.GetClient(),
		Scheme:   mgr.GetScheme(),
		OwnerKey: ownerKey,
		OwnerVal: ownerVal,
	}

	nsControllerBuilder := ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Namespace{}).
		WithOptions(controller.Options{
			MaxConcurrentReconciles: maxConcurrentReconciles,
		})

	if enableConcurrencyOptimizations {
		logger.Info("concurrency optimizations enabled for NamespaceReconciler")
		// Adicionar configurações específicas de concorrência se necessário
	}

	if err := nsControllerBuilder.Complete(nsReconciler); err != nil {
		panic(fmt.Errorf("cannot setup NamespaceReconciler: %w", err))
	}

	// Setup NodeReconciler com configurações de concorrência
	nodeReconciler := &controllers.NodeReconciler{
		Client:        mgr.GetClient(),
		Scheme:        mgr.GetScheme(),
		GPULabelKey:   gpuNodeLabelKey,
		GPULabelValue: gpuNodeLabelVal,
		TaintKey:      taintKey,
		TaintValue:    taintVal,
		TaintEffect:   corev1.TaintEffect(taintEffect),
	}

	nodeControllerBuilder := ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Node{}).
		WithOptions(controller.Options{
			MaxConcurrentReconciles: maxConcurrentReconciles,
		})

	if enableConcurrencyOptimizations {
		logger.Info("concurrency optimizations enabled for NodeReconciler")
		// Adicionar configurações específicas de concorrência se necessário
	}

	if err := nodeControllerBuilder.Complete(nodeReconciler); err != nil {
		panic(fmt.Errorf("cannot setup NodeReconciler: %w", err))
	}

	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		panic(fmt.Errorf("cannot set healthz: %w", err))
	}
	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		panic(fmt.Errorf("cannot set readyz: %w", err))
	}

	logger.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		panic(fmt.Errorf("problem running manager: %w", err))
	}
}

func getEnv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
