#!/bin/bash

# Depo, kullanıcı ve log dosyalarının kontrolü
depoDosya="depo.csv"
kullaniciDosya="kullanici.csv"
logDosya="log.csv"

# Bu dosyalar daha önceden yoksa sütun başlıklarıyla beraber otomatik olarak oluşturulur.
if [[ ! -f $depoDosya ]]; then
    touch $depoDosya
    echo "Urun Numarası,Urun Adi,Stok Miktari,Birim Fiyati,Kategori" > $depoDosya
fi

if [[ ! -f $kullaniciDosya ]]; then
    touch $kullaniciDosya
    echo "No,Ad,Rol,Parola,Giris Denemesi" > $kullaniciDosya
    # Hiç hesap yoksa programı kullanabilmek için adı admin şifresi admin olan bir hesap oluşturulur.
    echo "1,admin,Yonetici,21232f297a57a5a743894a0e4a801fc3,0" >> $kullaniciDosya
fi

if [[ ! -f $logDosya ]]; then
    touch $logDosya
    echo "Kayit Numarasi,Guncel Tarih,Kayit Bilgisi,Kullanici Bilgisi,Urun Bilgisi" > $logDosya
fi

# İlerleme çubuğu fonksiyonu
# Bu fonksiyon 2 saniye boyunca 0'dan 100'e bir bar doldurur.
ilerleme_cubugu() {
	( 
	  for i in {1..100}
	  do
		echo $i
		echo "# İlerleme: $i%"
		sleep 0.02
	  done
	) | zenity --progress --title="İşlem Yükleniyor" --text="İşlem devam ediyor..." --percentage=0 --auto-close
}

# Kayit loglama fonksiyonu
# Bu fonksiyon aşağıdaki gibi 3 argüman alır. Log dosyasına argümanlara göre kayıt alır.
# 1. arg -> Kayıt bilgisi
# 2. arg -> Kullanıcı bilgisi
# 3. arg -> Ürün bilgisi
kayit_logla() {
	kayitBilgisi=$1
	kullaniciBilgisi=$2
	urunBilgisi=$3
	kayitNo=$(($(wc -l < $logDosya))) # Eşşiz bir kayıt numarası oluşturma
	zenity --error --text="$kayitBilgisi"
    guncelTarih=$(date '+%Y-%m%d %H:%M:%S')
    echo "$kayitNo,$guncelTarih,$kayitBilgisi,$kullaniciBilgisi,$urunBilgisi" >> ./log.csv
}

# Giriş ekranı
# Bu fonksiyon program ilk açıldığında çalışan fonksiyondur. Kullanıcıdan form ile giriş bilgilerini ister.
giris_yap() {
	kullaniciBilgi=$(zenity --forms --title="Giriş Yap" \
	    --text="Lütfen giriş bilgilerinizi giriniz." \
	    --add-entry="Kullanıcı Adı" \
	    --add-password="Parola")
	
	# Kullanıcı giriş bilgileri girdi mi
	if [[ -z "$kullaniciBilgi" ]]; then
	   	kayit_logla "Giriş iptal edildi!" "None" "None"
	    exit 1
	fi
	
	# Kullanıcı giriş bilgilerini parçalama
	kullaniciAd=$(echo "$kullaniciBilgi" | cut -d '|' -f 1)
	kullaniciParola=$(echo "$kullaniciBilgi" | cut -d '|' -f 2)
	hashKullaniciParola=$(echo -n "$kullaniciParola" | md5sum | awk '{print $1}')

	# Girilen ada ve parolaya uygun kullanıcıyı bulma
	kullaniciKaydi=$(grep -i ",$kullaniciAd," $kullaniciDosya | grep -w "$hashKullaniciParola")
	
	# Bu kullanıcının giriş denemesi tutacak değişken
	kullaniciKilit=$(grep -i ",$kullaniciAd," $kullaniciDosya | awk -F',' '{print $5}')
	kullaniciRolKontrol=$(grep -i ",$kullaniciAd," $kullaniciDosya | awk -F',' '{print $3}')
	
	ilerleme_cubugu
	
	# Girilen bilgilere ait bir kullanıcı bulunamazsa
	if [[ -z "$kullaniciKaydi" ]]; then
		kayit_logla "Kullanıcı adı veya parola hatalı!" "None" "None"
		
		# Eğer ki girmeye çalışan kişi adminse hesabının kilitlenemiyor olması sağlanır.
		if [[ kullaniciRolKontrol != Yonetici ]]; then
			((kullaniciKilit++))
		fi	
		# Güncellenmiş bilgileri dosyaya yazmak için geçici bir dosya oluştur.
    	tmpDosya=$(mktemp)
		
		# Kullanıcının giriş denemesi sayısını güncelle
    	awk -F, -v kullaniciDurum="$kullaniciKilit" -v kullaniciAd="$kullaniciAd"\
        'BEGIN {OFS=","} {if ($2 == kullaniciAd) {$5 = kullaniciDurum} print $0}' $kullaniciDosya > $tmpDosya
        
		# Eski dosyayı yedekle
		mv $kullaniciDosya "${kullaniciDosya}.bak"

		# Güncellenmiş dosyayı orijinal adıyla kaydet.
		mv $tmpDosya $kullaniciDosya
		      
        if [[ $kullaniciKilit == 3 ]]; then
        	kayit_logla "3 kere hatalı giriş yapıldı, hesap kitleniyor!" $kullaniciAd "None"
        fi
	    giris_yap
	    
	# Girilen bilgilere ait bir kullanıcı bulunur ancak hesap kilitliyse	    
	elif [[ $kullaniciKilit -gt 2 ]]; then
		kayit_logla "Kilitli hesaba giriş denemesi! Lütfen bir yöneticiyle iletişime geçin." $kullaniciAd "None"	
		giris_yap
		
	# Giriş yapmada herhangi bir problem yaşanmadıysa		 
	else
	    zenity --info --text="Giriş başarılı!"	    
	    tmpDosya=$(mktemp)
		
		# Kullanıcının giriş deneme sayısını 0'a eşitle.
    	awk -F, -v kullaniciDurum=0 -v kullaniciAd="$kullaniciAd"\
        'BEGIN {OFS=","} {if ($2 == kullaniciAd) {$5 = kullaniciDurum} print $0}' $kullaniciDosya > $tmpDosya
        
		# Eski dosyayı yedekle
		mv $kullaniciDosya "${kullaniciDosya}.bak"

		# Güncellenmiş dosyayı orijinal adıyla kaydet.
		mv $tmpDosya $kullaniciDosya
	    
	    # Kullanıcıyı ana menüye rolüyle beraber yönlendir.
	    kullaniciRol=$(echo "$kullaniciKaydi" | cut -d ',' -f 3)
	    ana_menu "$kullaniciRol"
	fi
		
}

# Ürün ekleme fonksiyonu
# Bu fonksiyon kullanıcıdan bir form ile ürün bilgilerini ister. Herhangi bir problem karşılaşılmazsa depo.csv'ye ürünü ekler.
urun_ekle() {
    urunBilgi=$(zenity --forms --title="Ürün Ekle" \
        --text="Yeni ürün bilgilerini giriniz." \
        --add-entry="Ürün Adı" \
        --add-entry="Stok Miktarı" \
        --add-entry="Birim Fiyatı" \
        --add-entry="Kategori")
	
	ilerleme_cubugu
	
    if [[ -z "$urunBilgi" ]]; then
    	kayit_logla "Ürün bilgisi girilmedi!" $kullaniciAd "None"
        return
    fi
    
    # Ürün bilgilerini parçalama
    urunAd=$(echo "$urunBilgi" | cut -d '|' -f 1)
    urunStok=$(echo "$urunBilgi" | cut -d '|' -f 2)
    urunBirimFiyat=$(echo "$urunBilgi" | cut -d '|' -f 3)
    urunKategori=$(echo "$urunBilgi" | cut -d '|' -f 4)
    
    # Aynı adda başka ürün varsa hata ver
    if grep -qi ",$urunAd," $depoDosya; then
        kayit_logla "Bu ürün adıyla başka bir kayıt bulunmaktadır. Lütfen farklı bir ad giriniz!" $kullaniciAd $urunAd  
    
    # Aynı adda başka ürün yoksa verilen kriterlere göre ürünü ekle     
    else
        if [[ "$urunAd" != *" "* && "$urunKategori" != *" "* && $urunStok =~ ^[0-9]+$ && $urunStok -ge 0 && $urunBirimFiyat =~ ^[0-9]+$ && $urunBirimFiyat -ge 0 ]]; then
            
			# Ürün numarasını benzersiz olarak atama
            urunNo=$(($(wc -l < $depoDosya)))

            # Ürün bilgilerini CSV dosyasına yazma
            echo "$urunNo,$urunAd,$urunStok,$urunBirimFiyat,$urunKategori" >> $depoDosya

            zenity --info --text="Ürün başarıyla eklendi!"
        else
        	kayit_logla "Geçersiz giriş! Ürün adında ve kategorisinde boşluk, stok ve fiyatta negatif sayı kullanmayın." $kullaniciAd $urunAd
        fi
    fi
}

# Ürün listeleme fonksiyonu
# Bu fonksiyon ürünleri listeler.
urun_listele(){
	ilerleme_cubugu 
	zenity --text-info --width=500 --height=300 --title="Ürün Listesi" --filename=$depoDosya
}

# Ürün güncelleme fonksiyonu
# Bu fonksiyon ile kullanıcıdan alınan ürün adına göre problemle karşılaşılmazsa bilgilerinde güncelleme yapılır.
urun_guncelle(){
    # Mevcut ürünlerin listesini al
    urunler=$(awk -F, 'NR>1 {print $1}' $depoDosya)
    
    # Eğer depo dosyasındaki ürünler boşsa, kullanıcıya bilgi ver.
    if [[ -z "$urunler" ]]; then
        kayit_logla "Ürün listesi boş güncelleme başarısız!" $kullaniciAd "None"
        return
    fi
    
    # Kullanıcıya ürünün adına göre ürün seçtirtme
    urunSecim=$(zenity --forms --title="Ürün Güncelle" \
        --text="Ürün adı girin:" \
        --add-entry="")
      
    # Kullanıcı bir ürün seçmezse işlemden çık.
    if [[ -z "$urunSecim" ]]; then
        kayit_logla "Güncellenmesi gereken ürün seçilmedi!" $kullaniciAd "None"       
        return
    fi
    
    # Kullanıcı tarafından girilen ürünü dosyada bulma
    urunKaydi=$(grep -i ",$urunSecim," $depoDosya | head -n 1)
    
    # Eğer ürün bulunamazsa hata mesajı ver.
    if [[ -z "$urunKaydi" ]]; then
        kayit_logla "Ürün bulunamadı güncelleme başarısız!" $kullaniciAd $urunKaydi
        return
    fi
    
    # Ürün bilgilerini ayır
    urunNo=$(echo "$urunKaydi" | cut -d ',' -f 1)
    urunAd=$(echo "$urunKaydi" | cut -d ',' -f 2)
    urunStok=$(echo "$urunKaydi" | cut -d ',' -f 3)
    urunBirimFiyat=$(echo "$urunKaydi" | cut -d ',' -f 4)
    urunKategori=$(echo "$urunKaydi" | cut -d ',' -f 5)

    # Kullanıcıdan güncellenecek bilgileri al
    yeniUrunBilgi=$(zenity --forms --title="Ürün Güncelle" \
        --text="Ürün bilgilerini güncelleyin." \
        --add-entry="Ürün Adı" \
        --add-entry="Stok Miktarı" \
        --add-entry="Birim Fiyatı" \
        --add-entry="Kategori")
    
    ilerleme_cubugu
    
    # Eğer bilgi girilmediyse işlemden çık
    if [[ -z "$yeniUrunBilgi" ]]; then
        kayit_logla "Ürün bilgisi girilmedi!" $kullaniciAd "None"
        return
    fi

    # Yeni bilgileri ayır
    yeniUrunAd=$(echo "$yeniUrunBilgi" | cut -d '|' -f 1)
    yeniUrunStok=$(echo "$yeniUrunBilgi" | cut -d '|' -f 2)
    yeniUrunBirimFiyat=$(echo "$yeniUrunBilgi" | cut -d '|' -f 3)
    yeniUrunKategori=$(echo "$yeniUrunBilgi" | cut -d '|' -f 4)

    # Yeni girilen bilgiler kriterlere uyuyor mu kontrol et
    if [[ "$yeniUrunAd" != *" "* && "$yeniUrunKategori" != *" "* && $yeniUrunStok =~ ^[0-9]+$ && $yeniUrunStok -ge 0 && $yeniUrunBirimFiyat =~ ^[0-9]+$ && $yeniUrunBirimFiyat -ge 0 ]]; then
        # Güncellenmiş ürünü dosyaya yazmak için geçici bir dosya oluştur
        tmpDosya=$(mktemp)

        # Ürünü güncelle
        awk -F, -v urunNo="$urunNo" -v yeniUrunAd="$yeniUrunAd" -v yeniUrunStok="$yeniUrunStok" -v yeniUrunBirimFiyat="$yeniUrunBirimFiyat" -v yeniUrunKategori="$yeniUrunKategori" \
            'BEGIN {OFS=","} {if ($1 == urunNo) {$2 = yeniUrunAd; $3 = yeniUrunStok; $4 = yeniUrunBirimFiyat; $5 = yeniUrunKategori} print $0}' $depoDosya > $tmpDosya

        # Eski dosyayı yedekle
        mv $depoDosya "${depoDosya}.bak"

        # Güncellenmiş dosyayı orijinal adıyla kaydet
        mv $tmpDosya $depoDosya

        zenity --info --text="Ürün başarıyla güncellendi!"
    else
        kayit_logla "Geçersiz giriş! Lütfen geçerli bilgiler girin." $kullaniciAd $yeniUrunAd
    fi
}

# Ürün silme fonksiyonu
# Bu fonksiyon ile kullanıcının istediği ürün bir problemle karşılaşılmazsa silinir.
urun_sil() {
    # Mevcut ürünlerin listesini al
    urunler=$(awk -F, 'NR>1 {print $1}' $depoDosya)
    
    # Eğer depo dosyasındaki ürünler boşsa, kullanıcıya bilgi ver
    if [[ -z "$urunler" ]]; then
        kayit_logla "Ürün listesi boş güncelleme başarısız!" $kullaniciAd "None"
        return
    fi
    
    # Kullanıcıdan silinecek ürünün bilgileri al
    urunSecim=$(zenity --forms --title="Ürün Sil" \
        --text="Ürün adı girin:" \
        --add-entry="")
    
    # Kullanıcı bir seçim yapmadıysa işlemden çık
    if [[ -z "$urunSecim" ]]; then
        kayit_logla "Güncellenmesi gereken ürün seçilmedi!" $kullaniciAd "None"
        return
    fi
    
    # Kullanıcı tarafından girilen ürünü dosyada bulma
    urunKaydi=$(grep -i ",$urunSecim," $depoDosya | head -n 1)
    
    # Eğer ürün bulunmazsa hata mesajı ver
    if [[ -z "$urunKaydi" ]]; then
        kayit_logla "Ürün bulunamadı güncelleme başarısız!" $kullaniciAd $urunKaydi
        return
    fi
    
    # Ürün bilgilerini ayır
    urunNo=$(echo "$urunKaydi" | cut -d ',' -f 1)
    urunAd=$(echo "$urunKaydi" | cut -d ',' -f 2)

    # Kullanıcıya silme işlemi onayının sorulması
    onay=$(zenity --question --title="Ürün Sil" \
        --text="Bu ürünü silmek istediğinizden emin misiniz?\n\nÜrün Adı: $urunAd" \
        --ok-label="Evet" --cancel-label="Hayır")
    
    ilerleme_cubugu
    
    # Eğer kullanıcı onay vermezse işlemden çık
    if [[ $? -ne 0 ]]; then
        return
    fi
    
    # Ürünü dosyadan silmek için geçici bir dosya oluştur
    tmpDosya=$(mktemp)

    # Ürünü sil, diğer tüm satırları geçici dosyaya yaz
    awk -F, -v urunNo="$urunNo" 'BEGIN {OFS=","} NR==1 {print $0} NR>1 {if ($1 != urunNo) print $0}' $depoDosya > $tmpDosya
    
    # Eski dosyayı yedekle
    mv $depoDosya "${depoDosya}.bak"
    
    # Yeni dosyada numaraları yeniden sırala
	awk -F, 'BEGIN {OFS=","} NR==1 {print $0} NR>1 { $1 = NR-1; print $0 }' $tmpDosya > $depoDosya
	
    zenity --info --text="Ürün başarıyla silindi!"  
}

# Rapor alma fonksiyonu
# Stoğu 50'den az olan ürünleri ve en yüksek stoğa sahip ürünü öğrenmek için kullanılır.
rapor_al(){
	secim=$(zenity --list --width=400 --height=250 --title="Rapor" --column="Seçenekler" \
        "Stoğu 50'nin altında olan ürünler" \
        "En fazla stoğa sahip ürün" \
        "Ürünlerin toplam değeri" \
        "Geri Git")

    case $secim in
        "Stoğu 50'nin altında olan ürünler")    
        	ilerleme_cubugu
        	
            # Stok miktarı 50'den az olan ürünleri filtrele
    		stokAlti=$(awk -F, '$3 < 50 {print $1 " " $2 " " $3 " " $4 " " $5}' $depoDosya)
    		
    		# Stoğu 50'den az olan ürünleri göster
			if [[ -z "$stokAlti" ]]; then
				zenity --info --text="Stok miktarı 50'den az olan ürün bulunmamaktadır."
			else
				zenity --info --title="Stoğu 50'den Az Olan Ürünler" --text="$stokAlti"
			fi
			rapor_al
            ;;
    	"En fazla stoğa sahip ürün")	
    		ilerleme_cubugu
    		
    		# En fazla stoğa sahip ürünü bul
    		enFazlaStok=$(awk -F, 'NR > 1 {if ($3 > max) {max=$3; urun=$2}} END {print urun, max}' $depoDosya)
    
    		# En fazla stoğa sahip ürünü göster
			if [[ -z "$enFazlaStok" ]]; then
				zenity --info --text="En fazla stoğa sahip ürün bulunamadı."
			else
				zenity --info --title="En Fazla Stoğa Sahip Ürün" --text="Ürün adı ve stoğu: $enFazlaStok"
			fi
			rapor_al
			;;
		"Ürünlerin toplam değeri")
			ilerleme_cubugu
		
			# Ürünleri stok miktarı ve birim fiyatı ile çarp toplam değeri hesapla
			toplamDeger=$(awk -F, 'NR > 1 {
				stokMiktari = $3;
				birimFiyat = $4;
				toplamDeger += stokMiktari * birimFiyat;
			} END { print toplamDeger }' $depoDosya)
			
			zenity --info --title="Toplam Değer" --text="Ürünlerin Toplam Değeri: $toplamDeger"	
			rapor_al		
			;;
		"Geri git")
			return
			;;
	esac
}

# Kullanıcı yönetimi fonksiyonu
# Bu fonksiyon sayesinde kullanıcı yönetimi ekranındaki seçimler yapılabilir.
kullanici_yonetimi() {
    while true; do
        secim=$(zenity --height=350 --list --title="Kullanıcı Yönetimi" \
            --column="Seçenekler" "Yeni Kullanıcı Ekle" "Kullanıcıları Listele" "Kullanıcı Güncelle" "Kullanıcı Sil" "Geri Git")
        
        # Seçimlere göre gerekli fonksiyonlara gider.
        case $secim in
            "Yeni Kullanıcı Ekle")
                yeni_kullanici_ekle
                ;;
            "Kullanıcıları Listele")
                kullanici_listele
                ;;
            "Kullanıcı Güncelle")
                kullanici_guncelle
                ;;
            "Kullanıcı Sil")
                kullanici_sil
                ;;
            "Geri Git")
                return
                ;;
        esac
    done
}

# Yeni kullanıcı ekleme fonksiyonu
# Bu fonksiyon bir problemle karşılaşmazsa girilen değerlere göre yeni bir kullanıcı oluşturur.
yeni_kullanici_ekle() {
    kullaniciBilgi=$(zenity --forms --title="Yeni Kullanıcı Ekle" \
        --text="Yeni kullanıcı bilgilerini giriniz." \
        --add-entry="Ad" \
        --add-entry="Rol (Yonetici / Kullanici)" \
        --add-password="Parola")
    
    ilerleme_cubugu
    
    # Kullanıcı bilgisi girilmediyse hata ver.
    if [[ -z "$kullaniciBilgi" ]]; then
        kayit_logla "Yeni kullanıcı bilgisi girilmedi!" $kullaniciAd "None"
        return
    fi
    
    # Girilen bilgileri parçala
    kullaniciAd=$(echo "$kullaniciBilgi" | cut -d '|' -f 1)
    kullaniciRol=$(echo "$kullaniciBilgi" | cut -d '|' -f 2)
    kullaniciParola=$(echo "$kullaniciBilgi" | cut -d '|' -f 3)
    
    # Parolayı hash'le (MD5)
    hashKullaniciParola=$(echo -n "$kullaniciParola" | md5sum | awk '{print $1}')

    # Oluşturulan kullanıcı bilgilerini dosyaya yaz
    kullaniciNo=$(($(wc -l < $kullaniciDosya)))
    echo "$kullaniciNo,$kullaniciAd,$kullaniciRol,$hashKullaniciParola,0" >> $kullaniciDosya

    zenity --info --text="Yeni kullanıcı başarıyla eklendi!"
}

# Kullanıcıları listeleme fonksiyonu
# Bu fonksiyon sayesinde kullanici.csv dosyası ekrana yazdırılır.
kullanici_listele() {
    ilerleme_cubugu
    zenity --text-info --width=500 --height=300 --title="Kullanıcı Listesi" --filename=$kullaniciDosya
}

# Kullanıcı güncelleme fonksiyonu
# Bu fonksiyonda herhangi bir problem ile karşılaşılmazsa belirli kriterlere göre kullanıcı oluşturulur.
kullanici_guncelle() {
    # Mevcut kullanıcıların listesini al
    kullanicilar=$(awk -F, 'NR>1 {print $1 " " $2}' $kullaniciDosya)
    
    # Liste boşsa hata ver.
    if [[ -z "$kullanicilar" ]]; then
        kayit_logla "Kullanıcı listesi boş güncelleme başarısız!" $kullaniciAd "None"
        return
    fi
    
    # Kullanıcıya güncellenecek kullanıcıyı seçtirtme
    kullaniciSecim=$(zenity --forms --title="Kullanıcı Güncelle" \
        --text="Güncellemek istediğiniz kullanıcıyı seçin:" \
        --add-entry="Kullanıcı Adı")
    
    if [[ -z "$kullaniciSecim" ]]; then
        kayit_logla "Güncellenmesi gereken kullanıcı seçilmedi!" $kullaniciAd "None"
        return
    fi
    
    # Kullanıcıyı dosyada arama
    kullaniciKaydi=$(grep -i ",$kullaniciSecim," $kullaniciDosya | head -n 1)
    
    if [[ -z "$kullaniciKaydi" ]]; then
        kayit_logla "Kullanıcı bulunamadı güncelleme başarısız!" $kullaniciAd "$kullaniciSecim"
        return
    fi
    
    # Kullanıcı bilgilerini ayırma
    kullaniciNo=$(echo "$kullaniciKaydi" | cut -d ',' -f 1)
    kullaniciAd=$(echo "$kullaniciKaydi" | cut -d ',' -f 2)
    kullaniciRol=$(echo "$kullaniciKaydi" | cut -d ',' -f 3)
    kullaniciParola=$(echo "$kullaniciKaydi" | cut -d ',' -f 4)
    kullaniciDurum=$(echo "$kullaniciKaydi" | cut -d ',' -f 5)

    # Kullanıcıdan yeni bilgiler alınması
    yeniKullaniciBilgi=$(zenity --forms --title="Kullanıcı Güncelle" \
        --text="Kullanıcı bilgilerini güncelleyin." \
        --add-entry="Ad" \
        --add-entry="Rol (Yonetici / Kullanici)" \
        --add-password="Parola" \
        --add-entry="Durum: (0 aktif, 3 pasif)")
    
    ilerleme_cubugu
    
    if [[ -z "$yeniKullaniciBilgi" ]]; then
        kayit_logla "Kullanıcı bilgisi girilmedi!" $kullaniciAd "None"
        return
    fi

    # Yeni bilgileri ayır
    yeniKullaniciAd=$(echo "$yeniKullaniciBilgi" | cut -d '|' -f 1)
    yeniKullaniciRol=$(echo "$yeniKullaniciBilgi" | cut -d '|' -f 2)
    yeniKullaniciParola=$(echo "$yeniKullaniciBilgi" | cut -d '|' -f 3)
    yeniKullaniciDurum=$(echo "$yeniKullaniciBilgi" | cut -d '|' -f 4)

    # Parolayı hash'le (MD5)
    yeniHashKullaniciParola=$(echo -n "$yeniKullaniciParola" | md5sum | awk '{print $1}')

    # Güncellenmiş bilgileri dosyaya yazmak için geçici bir dosya oluştur
    tmpDosya=$(mktemp)

    # Kullanıcıyı güncelle
    awk -F, -v kullaniciNo="$kullaniciNo" -v yeniKullaniciAd="$yeniKullaniciAd" \
        -v yeniKullaniciRol="$yeniKullaniciRol" -v yeniHashKullaniciParola="$yeniHashKullaniciParola" -v yeniKullaniciDurum="$yeniKullaniciDurum" \
        'BEGIN {OFS=","} {if ($1 == kullaniciNo) {$2 = yeniKullaniciAd; $3 = yeniKullaniciRol; $4 = yeniHashKullaniciParola; $5 = yeniKullaniciDurum} print $0}' $kullaniciDosya > $tmpDosya

    # Eski dosyayı yedekle
    mv $kullaniciDosya "${kullaniciDosya}.bak"

    # Güncellenmiş dosyayı orijinal adıyla kaydet
    mv $tmpDosya $kullaniciDosya

    zenity --info --text="Kullanıcı başarıyla güncellendi!"
}

# Kullanıcı silme fonksiyonu
# Bu fonksiyonda hata ile karşılaşılmazsa kullanıcı silinir.
kullanici_sil() {
    # Mevcut kullanıcıların listesini al
    kullanicilar=$(awk -F, 'NR>1 {print $1 " " $2}' $kullaniciDosya)
    
    if [[ -z "$kullanicilar" ]]; then
        kayit_logla "Kullanıcı listesi boş silme başarısız!" $kullaniciAd "None"
        return
    fi
    
    # Kullanıcıdan silinecek kullanıcının adının alınması
    kullaniciSecim=$(zenity --forms --title="Kullanıcı Sil" \
        --text="Silmek istediğiniz kullanıcıyı seçin:" \
        --add-entry="Kullanıcı Adı")
    
    if [[ -z "$kullaniciSecim" ]]; then
        kayit_logla "Silinmesi gereken kullanıcı seçilmedi!" $kullaniciAd "None"
        return
    fi
    
    # Silinecek kullanıcıyı dosyada arama
    kullaniciKaydi=$(grep -i ",$kullaniciSecim," $kullaniciDosya | head -n 1)
    
    if [[ -z "$kullaniciKaydi" ]]; then
        kayit_logla "Kullanıcı bulunamadı silme başarısız!" $kullaniciAd "$kullaniciSecim"
        return
    fi
    
    # Silinecek kullanıcının bilgilerini ayır
    kullaniciNo=$(echo "$kullaniciKaydi" | cut -d ',' -f 1)
    kullaniciAd=$(echo "$kullaniciKaydi" | cut -d ',' -f 2)

    # Kullanıcıya silme işlemi onayı sorulacak
    onay=$(zenity --question --title="Kullanıcı Sil" \
        --text="Bu kullanıcıyı silmek istediğinizden emin misiniz?\n\nKullanıcı Adı: $kullaniciAd" \
        --ok-label="Evet" --cancel-label="Hayır")
    
    ilerleme_cubugu
    
    # Eğer kullanıcı onay vermezse işlemden çık
    if [[ $? -ne 0 ]]; then
        return
    fi
    
    # Kullanıcıyı dosyadan silmek için geçici bir dosya oluştur
    tmpDosya=$(mktemp)

    # Kullanıcıyı sil, diğer tüm satırları geçici dosyaya yaz
    awk -F, -v kullaniciNo="$kullaniciNo" 'BEGIN {OFS=","} {if ($1 != kullaniciNo) print $0}' $kullaniciDosya > $tmpDosya

    # Eski dosyayı yedekle
    mv $kullaniciDosya "${kullaniciDosya}.bak"
    
    # Yeni dosyada kullanıcı numaralarını yeniden sırala
	awk -F, 'BEGIN {OFS=","} NR==1 {print $0} NR>1 { $1 = NR-1; print $0 }' $tmpDosya > $kullaniciDosya

    zenity --info --text="Kullanıcı başarıyla silindi!"
}

# Program yönetimi fonksiyonu
# Bu fonksiyon ile diskte kalan boş yeri öğrenebilir, programı yedekleyebilir ya da hata kayıtlarına bakabilirsiniz.
program_yonetimi() {
    # Zenity ile kullanıcıya seçenekler sun
    secim=$(zenity --list --title="Program Yönetimi" --column="Seçenekler" \
        "Diskteki Alanı Göster" \
        "Diske Yedekle" \
        "Hata Kayıtlarını Göster" \
        "Geri Git")

    case $secim in
        "Diskteki Alanı Göster")
        
        	ilerleme_cubugu
        	
            # df komutunu kullanarak disk alanını göster
            diskAlani=$(df -h . | awk 'NR==2 {print $3 " / " $2 " kullanılabilir"}')
            zenity --info --text="Diskteki alan: $diskAlani"
            program_yonetimi
            ;;
        
        "Diske Yedekle")
        
        	ilerleme_cubugu
        
            # Yedekleme işlemi
            guncelTarih=$(date +"%Y-%m-%d_%H-%M-%S")
            yedekDizin="yedek_$guncelTarih"
            mkdir -p "$yedekDizin"
            cp depo.csv kullanici.csv "$yedekDizin/"
            
            if [ $? -eq 0 ]; then
                zenity --info --text="Yedekleme başarılı, $yedekDizin dizinine kaydedildi!" "$kullaniciAd" "None"
            else
                kayit_logla "Yedekleme sırasında bir hata oluştu." $kullaniciAd "None"
            fi
            program_yonetimi
            ;;
        
        "Hata Kayıtlarını Göster")
        
        	ilerleme_cubugu
        
            # log.csv dosyasını göster
            if [ -f "log.csv" ]; then
                zenity --text-info --width=600 --height=500 --title="Hata Kayıtları" --filename="log.csv"
            else
                kayit_logla "log.csv dosyası bulunamadı." $kullaniciAd "None"
            fi
            program_yonetimi
            ;;
        
		"Geri Git")
			return
			;;
    esac
}

# Ana Menü
# Kullanıcının programda dolaşmasını sağlayan ana menü fonksiyonu.
ana_menu() {
	while true; do
		rol=$1		
		    secim=$(zenity --height=350 --list --title="Ana Menü" \
		        --column="Seçenekler" "Ürün Ekle" "Ürün Listele" "Ürün Güncelle" "Ürün Sil" "Rapor Al" "Kullanıcı Yönetimi" "Program Yönetimi" "Çıkış")
		    case $secim in
		        "Ürün Ekle")
		        	if [[ "$rol" == "Yonetici" ]]; then
		            	urun_ekle
		            else
		            	kayit_logla "Yetkisiz giriş denemesi!" $kullaniciAd "None"
		            fi
		            ;;
		        "Ürün Listele")
		            urun_listele
		            ;;
		        "Ürün Güncelle")
		        	if [[ "$rol" == "Yonetici" ]]; then
		            	urun_guncelle
		            else
		            	kayit_logla "Yetkisiz giriş denemesi!" $kullaniciAd "None"
		            fi            
		            ;;
		        "Ürün Sil")
		            if [[ "$rol" == "Yonetici" ]]; then
		            	urun_sil
		            else
		            	kayit_logla "Yetkisiz giriş denemesi!" $kullaniciAd "None"
		            fi 
		            ;;
		        "Rapor Al")
		            rapor_al
		            ;;
		        "Kullanıcı Yönetimi")
		            if [[ "$rol" == "Yonetici" ]]; then
		            	kullanici_yonetimi
		            else
		            	kayit_logla "Yetkisiz giriş denemesi!" $kullaniciAd "None"
		            fi 
		            ;;
		        "Program Yönetimi")
		            if [[ "$rol" == "Yonetici" ]]; then
		            	program_yonetimi
		            else
		            	kayit_logla "Yetkisiz giriş denemesi!" $kullaniciAd "None"
		            fi 
		            ;;
		        "Çıkış")
					zenity --question --title="Çıkış Ekranı" --text="Çıkış yapmak istediğinizden emin misiniz?"
					
					# Eğer kullanıcı "Evet" derse, çıkış yap
					if [[ $? -eq 0 ]]; then
						exit 0
					fi
					;;
		    esac
	done
}

# Giriş fonksiyonunu çağır
giris_yap

