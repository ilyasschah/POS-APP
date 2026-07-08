
using Api.Repository;
using MediatR;

namespace Api.Commands.BookingCommands.Add
{
    public class LinkPosOrderCommand : IRequest<bool>
    {
        public int CompanyId { get; }
        public int BookingId { get; }
        public int PosOrderId { get; }

        public LinkPosOrderCommand(int companyId, int bookingId, int posOrderId)
        {
            CompanyId = companyId;
            BookingId = bookingId;
            PosOrderId = posOrderId;
        }

        public class Handler : IRequestHandler<LinkPosOrderCommand, bool>
        {
            private readonly BookingRepository _bookingRepository;

            public Handler(BookingRepository bookingRepository)
            {
                _bookingRepository = bookingRepository;
            }

            public async Task<bool> Handle(LinkPosOrderCommand request, CancellationToken cancellationToken)
            {
                var booking = await _bookingRepository.GetByIdAsync(request.BookingId, request.CompanyId);
                if (booking == null) return false;

                booking.LinkPosOrder(request.PosOrderId);

                await _bookingRepository._db.SaveChangesAsync(cancellationToken);
                return true;
            }
        }
    }
}