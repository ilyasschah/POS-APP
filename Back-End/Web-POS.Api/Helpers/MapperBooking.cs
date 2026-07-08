using Api.Domain;
using Api.Models;

namespace Api.Helpers
{
    public class MapperBooking
    {
        public static BookingDto MapToDto(Booking booking)
        {
            return new BookingDto
            {
                Id = booking.Id,
                CustomerId = booking.CustomerId,
                UserId = booking.UserId,
                ReservationName = booking.ReservationName,
                TableIds = booking.TableIds,
                DocumentId = booking.DocumentId,
                PosOrderId = booking.PosOrderId,
                StartTime = booking.StartTime,
                EndTime = booking.EndTime,
                GuestCount = booking.GuestCount,
                Status = booking.Status,
                Note = booking.Note,
            };
        }
    }
}
