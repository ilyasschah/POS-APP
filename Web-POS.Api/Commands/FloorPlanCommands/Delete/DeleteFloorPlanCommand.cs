using MediatR;
using FluentValidation;
using Api.Services;

namespace Api.Commands.FloorPlanCommand.Delete
{
    public class DeleteFloorPlanCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public class DeleteFloorPlanCommandHandler : IRequestHandler<DeleteFloorPlanCommand, bool>
        {
            private readonly FloorPlanService _service;

            public DeleteFloorPlanCommandHandler(FloorPlanService service)
            {
                _service = service;
            }

            public async Task<bool> Handle(DeleteFloorPlanCommand command, CancellationToken cancellationToken)
            {
                return await _service.DeleteAsync(command.Id, command.CompanyId);
            }
        }
    }

    public class DeleteFloorPlanCommandValidator : AbstractValidator<DeleteFloorPlanCommand>
    {
        public DeleteFloorPlanCommandValidator()
        {
            RuleFor(x => x.Id)
                .GreaterThan(0).WithMessage("Id is required and must be greater than 0.");

            RuleFor(x => x.CompanyId)
                .GreaterThan(0).WithMessage("CompanyId is required and must be greater than 0.");
        }
    }
}