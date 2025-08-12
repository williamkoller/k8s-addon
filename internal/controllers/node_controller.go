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

type NodeReconciler struct {
	Client        client.Client
	Scheme        *runtime.Scheme
	GPULabelKey   string
	GPULabelValue string
	TaintKey      string
	TaintValue    string
	TaintEffect   corev1.TaintEffect
}

func (r *NodeReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	var node corev1.Node
	if err := r.Client.Get(ctx, req.NamespacedName, &node); err != nil {
		if apierrors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, fmt.Errorf("get node: %w", err)
	}

	hasGPULabel := node.Labels[r.GPULabelKey] == r.GPULabelValue
	taintWanted := corev1.Taint{
		Key:    r.TaintKey,
		Value:  r.TaintValue,
		Effect: r.TaintEffect,
	}

	taints := node.Spec.Taints
	hasTaint := false
	for _, t := range taints {
		if t.Key == taintWanted.Key && t.Value == taintWanted.Value && t.Effect == taintWanted.Effect {
			hasTaint = true
			break
		}
	}

	if hasGPULabel && !hasTaint {
		node.Spec.Taints = append(node.Spec.Taints, taintWanted)
		if err := r.Client.Update(ctx, &node); err != nil {
			return ctrl.Result{}, fmt.Errorf("update node: %w", err)
		}
	}

	return ctrl.Result{}, nil
}

func (r *NodeReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Node{}).
		Complete(r)
}
