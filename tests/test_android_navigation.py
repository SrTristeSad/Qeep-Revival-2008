"""Offline regression tests of screenshot geometry and image-difference checks."""
import sys
import unittest
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import android_navigation as nav


class AndroidNavigationTests(unittest.TestCase):
    def frame(self, scale=4.5, screen=(1080,1920)):
        im=Image.new('RGB',screen,(45,45,45))
        x=round((screen[0]-240*scale)/2)
        y=239
        draw=ImageDraw.Draw(im)
        draw.rectangle((x,y,x+240*scale-1,y+25*scale-1),fill=nav.PURPLE)
        draw.rectangle((x,y+295*scale,x+240*scale-1,y+320*scale-1),fill=nav.PURPLE)
        draw.rectangle((x,y+25*scale,x+240*scale-1,y+295*scale-1),fill=(235,255,185))
        return im

    def test_runs(self):
        self.assertEqual(nav.runs([1,2,4,8,9]),[(1,2),(4,4),(8,9)])

    def test_canvas_real_emulator_screenshot(self):
        real=Path(__file__).resolve().parents[1]/'evidence'/'emulator.png'
        if real.exists():
            with Image.open(real) as im:
                geo=nav.canvas(im)
                self.assertAlmostEqual(geo['scale'],4.5,places=2)
                self.assertGreaterEqual(geo['width_coverage'],.96)
                self.assertEqual(nav.logical_point(geo,120,307)[0],540)

    def test_identifies_canvas(self):
        geo=nav.canvas(self.frame())
        self.assertGreater(geo['width_coverage'],0.999)
        self.assertEqual(geo['top'],[239,350])
        self.assertEqual(geo['footer'],[1566,1678])

    def test_no_canvas(self):
        with self.assertRaisesRegex(ValueError,'2 Qeep purple bands'):
            nav.canvas(Image.new('RGB',(1080,1920),'black'))

    def test_wrong_scale(self):
        im=self.frame();draw=ImageDraw.Draw(im)
        draw.rectangle((5,239,5,350),fill='black')
        with self.assertRaises(ValueError):
            nav.canvas(im)

    def test_transition_detects_actual_content_change(self):
        menu=self.frame(); other=menu.copy()
        geo=nav.canvas(menu)
        draw=ImageDraw.Draw(other)
        x,y=nav.logical_point(geo,25,95)
        draw.rectangle((x,y,x+450,y+200),fill=(0,0,0))
        self.assertGreater(nav.pixels_changed(menu,other,geo),.035)
        self.assertEqual(nav.pixels_changed(menu,menu,geo),0)

    def test_differences_ignore_statusbar(self):
        original=self.frame(); edited=original.copy();ImageDraw.Draw(edited).rectangle((0,0,1079,80),fill=(255,255,255))
        self.assertEqual(nav.pixels_changed(original,edited,nav.canvas(original)),0)


if __name__=='__main__': unittest.main()
