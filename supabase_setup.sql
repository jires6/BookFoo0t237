-- Script d'initialisation des tables Supabase pour BookFoot237
-- À exécuter dans: Supabase Dashboard > SQL Editor

-- ===================================
-- 1. TABLE STADIUMS
-- ===================================

CREATE TABLE IF NOT EXISTS public.stadiums (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    adresse TEXT NOT NULL,
    quartier VARCHAR(100) NOT NULL,
    prix INTEGER NOT NULL,
    type VARCHAR(50) NOT NULL,
    capacite VARCHAR(100) NOT NULL,
    disponible BOOLEAN DEFAULT TRUE,
    description TEXT NOT NULL,
    gestionnaire VARCHAR(255) NOT NULL, -- Email du gestionnaire
    images TEXT[] DEFAULT '{}', -- Array d'URLs d'images
    horaires JSONB DEFAULT '{
        "lundi": {"ouvert": true, "debut": "06:00", "fin": "22:00"},
        "mardi": {"ouvert": true, "debut": "06:00", "fin": "22:00"},
        "mercredi": {"ouvert": true, "debut": "06:00", "fin": "22:00"},
        "jeudi": {"ouvert": true, "debut": "06:00", "fin": "22:00"},
        "vendredi": {"ouvert": true, "debut": "06:00", "fin": "22:00"},
        "samedi": {"ouvert": true, "debut": "06:00", "fin": "22:00"},
        "dimanche": {"ouvert": true, "debut": "08:00", "fin": "20:00"}
    }',
    amenities JSONB DEFAULT '{}', -- Commodités du stade
    date_creation TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===================================
-- 2. TABLE RESERVATIONS
-- ===================================

CREATE TABLE IF NOT EXISTS public.reservations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    stade_id UUID REFERENCES public.stadiums(id) ON DELETE CASCADE,
    stade_nom VARCHAR(255) NOT NULL,
    client_nom VARCHAR(255) NOT NULL,
    client_email VARCHAR(255) NOT NULL,
    date_reservation DATE NOT NULL,
    heure_debut TIME NOT NULL,
    heure_fin TIME NOT NULL,
    raison TEXT DEFAULT '',
    statut VARCHAR(50) DEFAULT 'en_attente', -- en_attente, confirmee, annulee, terminee
    date_creation TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===================================
-- 3. POLITIQUES DE SÉCURITÉ (RLS)
-- ===================================

-- Activer RLS sur les tables
ALTER TABLE public.stadiums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;

-- Politiques pour STADIUMS
-- Lecture : tous peuvent voir les stades disponibles
CREATE POLICY "Tous peuvent voir les stades disponibles" ON public.stadiums
    FOR SELECT USING (disponible = true);

-- Écriture : seuls les gestionnaires peuvent modifier leurs stades
CREATE POLICY "Gestionnaires peuvent gérer leurs stades" ON public.stadiums
    FOR ALL USING (gestionnaire = auth.jwt() ->> 'email');

-- Politiques pour RESERVATIONS
-- Lecture : clients voient leurs réservations, gestionnaires voient celles de leurs stades
CREATE POLICY "Clients voient leurs réservations" ON public.reservations
    FOR SELECT USING (client_email = auth.jwt() ->> 'email');

CREATE POLICY "Gestionnaires voient réservations de leurs stades" ON public.reservations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.stadiums
            WHERE stadiums.id = reservations.stade_id
            AND stadiums.gestionnaire = auth.jwt() ->> 'email'
        )
    );

-- Écriture : clients peuvent créer des réservations
CREATE POLICY "Clients peuvent créer des réservations" ON public.reservations
    FOR INSERT WITH CHECK (client_email = auth.jwt() ->> 'email');

-- Mise à jour : gestionnaires peuvent mettre à jour le statut
CREATE POLICY "Gestionnaires peuvent mettre à jour réservations" ON public.reservations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.stadiums
            WHERE stadiums.id = reservations.stade_id
            AND stadiums.gestionnaire = auth.jwt() ->> 'email'
        )
    );

-- ===================================
-- 4. INDEXES POUR PERFORMANCE
-- ===================================

-- Index sur les emails pour les recherches rapides
CREATE INDEX IF NOT EXISTS idx_stadiums_gestionnaire ON public.stadiums(gestionnaire);
CREATE INDEX IF NOT EXISTS idx_reservations_client_email ON public.reservations(client_email);
CREATE INDEX IF NOT EXISTS idx_reservations_stade_id ON public.reservations(stade_id);
CREATE INDEX IF NOT EXISTS idx_reservations_date ON public.reservations(date_reservation);

-- Index sur les critères de recherche fréquents
CREATE INDEX IF NOT EXISTS idx_stadiums_quartier ON public.stadiums(quartier);
CREATE INDEX IF NOT EXISTS idx_stadiums_type ON public.stadiums(type);
CREATE INDEX IF NOT EXISTS idx_stadiums_disponible ON public.stadiums(disponible);

-- ===================================
-- 5. FONCTIONS UTILITAIRES
-- ===================================

-- Fonction pour mettre à jour automatically updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour auto-update
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.stadiums
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.reservations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- ===================================
-- 6. DONNÉES D'EXEMPLE (OPTIONNEL)
-- ===================================

-- Insérer quelques stades d'exemple
INSERT INTO public.stadiums (nom, adresse, quartier, prix, type, capacite, description, gestionnaire)
VALUES
    ('Stade Central Yaoundé', 'Avenue Kennedy, Yaoundé', 'Yaoundé 1er', 15000, 'Football', '22 joueurs, 200 spectateurs', 'Stade de football moderne avec éclairage LED et vestiaires équipés', 'manager@example.com'),
    ('Terrain de Basket Mvog-Ada', 'Quartier Mvog-Ada', 'Yaoundé 3ème', 8000, 'Basketball', '10 joueurs, 50 spectateurs', 'Terrain de basketball couvert avec sol synthétique', 'manager@example.com'),
    ('Court de Tennis Nlongkak', 'Route de Nlongkak', 'Nlongkak', 12000, 'Tennis', '4 joueurs', 'Court de tennis professionnel avec surface dure', 'manager@example.com')
ON CONFLICT DO NOTHING;

-- ===================================
-- 7. PERMISSIONS POUR L'APPLICATION
-- ===================================

-- Autoriser l'accès anonyme pour la lecture (si nécessaire)
-- Les politiques RLS gèrent la sécurité

-- Vérification finale
SELECT 'Tables créées avec succès!' as message;