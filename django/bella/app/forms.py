from django import forms

from .models import Garment
from .models import GarmentPicture
from .models import Outfit
from .models import OutfitPicture


class PictureInput(forms.FileInput):
  template_name = "bella/form-widgets/picture.html"

  def format_value(self, value):
    return value


class GarmentForm(forms.ModelForm):
  class Meta:
    model = Garment
    fields = ["name"]

  outfits = forms.ModelMultipleChoiceField(queryset=Outfit.objects, required=False)

  def __init__(self, *args, **kwargs):
    kwargs.setdefault("initial", {}).setdefault("outfits", kwargs["instance"].outfits.all())
    super().__init__(*args, **kwargs)

  def save(self, *args, **kwargs):
    self.instance.outfits.set(self.cleaned_data["outfits"])
    return super().save(*args, **kwargs)


GarmentPictureFormSet = forms.inlineformset_factory(
  parent_model=Garment,
  model=GarmentPicture,
  fields=["file"],
  widgets={"file": PictureInput},
  extra=1,
  can_delete_extra=False,
)


class OutfitForm(forms.ModelForm):
  class Meta:
    model = Outfit
    fields = ["name", "garments"]


OutfitPictureFormSet = forms.inlineformset_factory(
  parent_model=Outfit,
  model=OutfitPicture,
  fields=["file"],
  widgets={"file": PictureInput},
  extra=1,
  can_delete_extra=False,
)
