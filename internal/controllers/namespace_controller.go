package controllers

import (
	"context"
	"fmt"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

type NamespaceReconciler struct {
	Client   client.Client
	Scheme   *runtime.Scheme
	OwnerKey string
	OwnerVal string
}

func (r *NamespaceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	var ns corev1.Namespace
	if err := r.Client.Get(ctx, req.NamespacedName, &ns); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, fmt.Errorf("get namespace: %w", err)
	}

	labels := ns.GetLabels()
	if labels == nil {
		labels = map[string]string{}
	}

	if labels[r.OwnerKey] == r.OwnerVal {
		return ctrl.Result{}, nil
	}

	labels[r.OwnerKey] = r.OwnerVal
	ns.SetLabels(labels)

	if err := r.Client.Update(ctx, &ns); err != nil {
		return ctrl.Result{}, fmt.Errorf("update namespace: %w", err)
	}

	return ctrl.Result{}, nil
}

func (r *NamespaceReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Namespace{}).
		Complete(r)
}
