using Api.Repository;
using Api.Services;
using FluentValidation;
using MediatR;
using Microsoft.OpenApi;

namespace Api.Commands.BookingCommands.Delete
{
    public class DeleteBookingCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }
        public int WarehouseId { get; } 

        public DeleteBookingCommand(int id, int companyId,int warehouseid)
        {
            Id = id;
            CompanyId = companyId;
            WarehouseId = warehouseid;
        }

        public class DeleteBookingCommandHandler : IRequestHandler<DeleteBookingCommand, bool>
        {
            private readonly BookingService _bookingService;
            private readonly PosOrderService _posOrderService;
            private readonly BookingRepository _bookingRepository;     
            private readonly PosOrderRepository _posOrderRepository;

            public DeleteBookingCommandHandler(
                BookingService bookingService,
                PosOrderService posOrderService,
                BookingRepository bookingRepository,
                PosOrderRepository posOrderRepository)
            {
                _bookingService = bookingService;
                _posOrderService = posOrderService;
                _bookingRepository = bookingRepository;
                _posOrderRepository = posOrderRepository;
            }

            public async Task<bool> Handle(DeleteBookingCommand request, CancellationToken cancellationToken)
            {
                var booking = await _bookingRepository.GetByIdAsync(request.Id, request.CompanyId);
                if (booking == null) return false;

                int? linkedPosOrderId = booking.PosOrderId;

                var bookingDeleted = await _bookingService.DeleteAsync(request.Id, request.CompanyId);

                if (bookingDeleted && linkedPosOrderId.HasValue)
                {
                    var posOrder = await _posOrderRepository.GetByIdAsync(linkedPosOrderId.Value, request.CompanyId);

                    if (posOrder != null)
                    {
                        await _posOrderService.Delete(posOrder.Id, request.CompanyId, request.WarehouseId);
                    }
                }

                return bookingDeleted;
            }
        }

        public class DeleteBookingCommandValidator : AbstractValidator<DeleteBookingCommand>
        {
            public DeleteBookingCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("Booking ID must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}