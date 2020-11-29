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


class BaseObjectWithPicturesView(View):
  def dispatch(self, request, obj_id=None):
    if obj_id is not None:
      obj = get_object_or_404(self.model, pk=obj_id)
    else:
      obj = None
    if request.method == "POST":
      if obj is not None and request.POST.get("submit") == "delete":
        obj.delete()
        return redirect(self.list_url, permanent=False)
      else:
        form = self.form_class(request.POST, request.FILES, instance=obj)
        picture_formset = self.picture_formset_class(
          request.POST, request.FILES, instance=form.instance
        )
        if form.is_valid() and picture_formset.is_valid():
          form.save()
          picture_formset.save()
          return redirect(self.detail_url, form.instance.id, permanent=False)
    else:
      form = self.form_class(instance=obj)
      picture_formset = self.picture_formset_class(instance=form.instance)
    model_name = self.model.__name__.lower()
    return render(
      request,
      self.template_name,
      {model_name: obj, f"{model_name}_form": form, "picture_formset": picture_formset,},
    )


class GarmentsView(ListView):
  template_name = "bella/garments.html"

  def get_queryset(self):
    return Garment.objects.all()


class GarmentView(BaseObjectWithPicturesView):
  model = Garment
  form_class = GarmentForm
  picture_formset_class = GarmentPictureFormSet
  template_name = "bella/garment.html"
  list_url = "garments"
  detail_url = "garment"


class OutfitsView(ListView):
  template_name = "bella/outfits.html"

  def get_queryset(self):
    return Outfit.objects.all()


class OutfitView(BaseObjectWithPicturesView):
  model = Outfit
  form_class = OutfitForm
  picture_formset_class = OutfitPictureFormSet
  template_name = "bella/outfit.html"
  list_url = "outfits"
  detail_url = "outfit"
