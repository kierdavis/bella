import re

from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.shortcuts import redirect
from django.shortcuts import render
from django.views import View
from django.views.generic import ListView

from .forms import GarmentForm
from .forms import GarmentPictureFormSet
from .forms import OutfitForm
from .forms import OutfitPictureFormSet
from .models import Garment
from .models import Outfit


def index(request):
  return redirect("garments", permanent=True)


class GarmentsView(ListView):
  template_name = "bella/garments.html"

  def get_queryset(self):
    return Garment.objects.all()


class GarmentView(View):
  def dispatch(self, request, obj_id=None):
    if obj_id is not None:
      obj = get_object_or_404(Garment, pk=obj_id)
    else:
      obj = None
    if request.method == "POST":
      if obj is not None and request.POST.get("submit") == "delete":
        obj.delete()
        return redirect("garments", permanent=False)
      else:
        form = GarmentForm(request.POST, request.FILES, instance=obj)
        picture_formset = GarmentPictureFormSet(
          request.POST, request.FILES, instance=form.instance
        )
        if form.is_valid() and picture_formset.is_valid():
          form.save()
          picture_formset.save()
          return redirect("garment", form.instance.id, permanent=False)
    else:
      form = GarmentForm(instance=obj)
      picture_formset = GarmentPictureFormSet(instance=form.instance)
    return render(
      request,
      "bella/garment.html",
      {"garment": obj, f"garment_form": form, "picture_formset": picture_formset},
    )


class OutfitsView(ListView):
  template_name = "bella/outfits.html"

  def get_queryset(self):
    return Outfit.objects.all()


class OutfitView(View):
  def dispatch(self, request, obj_id=None):
    if obj_id is not None:
      obj = get_object_or_404(Outfit, pk=obj_id)
    else:
      obj = None
    if request.method == "POST":
      if obj is not None and request.POST.get("submit") == "delete":
        obj.delete()
        return redirect("outfits", permanent=False)
      else:
        form = OutfitForm(request.POST, request.FILES, instance=obj)
        picture_formset = OutfitPictureFormSet(
          request.POST, request.FILES, instance=form.instance
        )
        if form.is_valid() and picture_formset.is_valid():
          form.save()
          picture_formset.save()
          return redirect("outfit", form.instance.id, permanent=False)
    else:
      form = OutfitForm(instance=obj)
      picture_formset = OutfitPictureFormSet(instance=form.instance)
    return render(
      request,
      "bella/outfit.html",
      {"outfit": obj, "outfit_form": form, "picture_formset": picture_formset},
    )
